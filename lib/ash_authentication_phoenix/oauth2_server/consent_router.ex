# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Oauth2Server.ConsentRouter do
  @moduledoc """
  Plug router for the human-driven consent step of the OAuth 2.1 flow.

  Handles `GET /authorize` (renders the consent screen) and
  `POST /authorize` (records the consent decision and redirects with a code).
  Both require a logged-in browser session — mount this behind your
  browser/session pipeline, not your API pipeline.

  See `AshAuthentication.Phoenix.Oauth2Server.ProtocolRouter` for the
  client-facing protocol endpoints (token, register, metadata).

  ## Options

    * `:oauth2_server` (required) — the user's `Oauth2Server` config module
    * `:consent_view` — module exposing `render(:consent, assigns)`
      (default: `AshAuthentication.Phoenix.Oauth2Server.ConsentView`)
  """

  use Plug.Router, copy_opts_to_assign: :oauth2_server_router_opts

  alias AshAuthentication.Oauth2Server
  alias AshAuthentication.Oauth2Server.Authorize
  alias AshAuthentication.Phoenix.Oauth2Server.{ConsentView, Errors}

  @max_state_bytes 2048
  @consent_request_salt "ash_authentication_phoenix oauth2_server consent_request v1"
  @consent_request_max_age 600

  plug Plug.Parsers,
    parsers: [:urlencoded],
    pass: ["*/*"]

  plug :match
  plug :dispatch

  get "/" do
    opts = conn.assigns.oauth2_server_router_opts
    handle_get(conn, server!(opts), opts)
  end

  post "/" do
    opts = conn.assigns.oauth2_server_router_opts
    handle_post(conn, server!(opts))
  end

  match _ do
    conn |> send_resp(404, "") |> halt()
  end

  # ── handlers ──────────────────────────────────────────────────────────────

  defp handle_get(conn, server, opts) do
    conn = fetch_query_params(conn)
    params = conn.query_params

    with :ok <- check_state_size(params),
         {:ok, validated} <- Authorize.validate_request(server, params),
         {:ok, user} <- require_user(conn) do
      if Authorize.consented?(server, user, validated.client, validated.scope) do
        issue_code_redirect(conn, server, user, validated)
      else
        render_consent(conn, validated, opts)
      end
    else
      {:error, :no_user} -> sign_in_redirect(conn, server)
      {:error, :bad_redirect_uri} -> bad_redirect_html(conn)
      {:error, :state_too_large} -> bad_state_html(conn)
      {:error, code, desc} -> handle_authorize_error(conn, server, params, code, desc)
    end
  end

  # The POST request fields are reconstructed from a sealed `consent_request`
  # token that was minted server-side at GET time. The form's own scope /
  # code_challenge / redirect_uri values are intentionally ignored — that
  # binds the user-visible consent UI to what we actually act on.
  defp handle_post(conn, server) do
    raw_params = conn.params

    case verify_consent_request(server, Map.get(raw_params, "consent_request")) do
      {:ok, sealed} ->
        handle_post_authorized(conn, server, raw_params, sealed_params(sealed))

      {:error, _} ->
        Errors.send_oauth_error(
          conn,
          400,
          "invalid_request",
          "consent request token missing, invalid, or expired"
        )
    end
  end

  defp handle_post_authorized(conn, server, raw_params, params) do
    with {:ok, validated} <- Authorize.validate_request(server, params),
         {:ok, user} <- require_user(conn) do
      case Map.get(raw_params, "action") do
        "approve" ->
          Authorize.grant_consent!(server, user, validated.client, validated.scope)

          conn
          |> rotate_session()
          |> issue_code_redirect(server, user, validated)

        "deny" ->
          redirect_with_oauth_error(
            conn,
            validated.redirect_uri,
            validated.state,
            "access_denied",
            nil
          )

        _ ->
          Errors.send_oauth_error(conn, 400, "invalid_request", "missing action")
      end
    else
      {:error, :no_user} -> sign_in_redirect(conn, server)
      {:error, :bad_redirect_uri} -> bad_redirect_html(conn)
      {:error, code, desc} -> handle_authorize_error(conn, server, params, code, desc)
    end
  end

  # ── shared helpers ────────────────────────────────────────────────────────

  defp server!(opts), do: Keyword.fetch!(opts, :oauth2_server)
  defp consent_view!(opts), do: Keyword.get(opts, :consent_view, ConsentView)

  defp require_user(conn) do
    case Ash.PlugHelpers.get_actor(conn) do
      nil -> {:error, :no_user}
      user -> {:ok, user}
    end
  end

  defp issue_code_redirect(conn, server, user, validated) do
    code = Authorize.issue_code!(server, user, validated)

    location =
      validated.redirect_uri <>
        "?" <> URI.encode_query(%{"code" => code.id, "state" => validated.state})

    conn
    |> put_resp_header("location", location)
    |> send_resp(302, "")
    |> halt()
  end

  # RFC 6749 §4.1.2.1: when redirect_uri has been validated for the client,
  # error responses MUST go back via 302 with `error`, `error_description`,
  # and `state` so the client can surface the failure to the end user.
  # When we can't safely validate the redirect_uri (unknown client, bad URI,
  # response_type bad before client was loaded), fall back to a direct
  # error response since redirecting an unverified URI is the worse failure
  # mode (open-redirect / token leak).
  defp handle_authorize_error(conn, server, params, code, desc) do
    case safe_redirect_uri(server, params) do
      {:ok, redirect_uri} ->
        redirect_with_oauth_error(conn, redirect_uri, Map.get(params, "state"), code, desc)

      :error ->
        Errors.send_oauth_error(conn, 400, code, desc)
    end
  end

  defp redirect_with_oauth_error(conn, redirect_uri, state, code, desc) do
    query =
      %{"error" => code}
      |> maybe_put_param("error_description", desc)
      |> maybe_put_param("state", state)

    conn
    |> put_resp_header("location", redirect_uri <> "?" <> URI.encode_query(query))
    |> send_resp(302, "")
    |> halt()
  end

  defp maybe_put_param(map, _key, nil), do: map
  defp maybe_put_param(map, _key, ""), do: map
  defp maybe_put_param(map, key, value), do: Map.put(map, key, value)

  defp safe_redirect_uri(server, %{"client_id" => client_id, "redirect_uri" => uri})
       when is_binary(client_id) and is_binary(uri) and client_id != "" and uri != "" do
    with {:ok, client} <- Ash.get(server.client_resource(), client_id, authorize?: false),
         registered when is_list(registered) <- Map.get(client, :redirect_uris) do
      normalized = Oauth2Server.__normalize_url__(uri)
      registered_normalized = Enum.map(registered, &Oauth2Server.__normalize_url__/1)
      if normalized in registered_normalized, do: {:ok, uri}, else: :error
    else
      _ -> :error
    end
  end

  defp safe_redirect_uri(_server, _params), do: :error

  defp check_state_size(%{"state" => state}) when is_binary(state) do
    if byte_size(state) > @max_state_bytes, do: {:error, :state_too_large}, else: :ok
  end

  defp check_state_size(_), do: :ok

  # Re-key the session on the anon→consented transition so a fixated
  # pre-login session id can't carry into the consented context.
  defp rotate_session(conn), do: Plug.Conn.configure_session(conn, renew: true)

  # sobelow_skip ["XSS.SendResp"]
  defp render_consent(conn, validated, opts) do
    view = consent_view!(opts)

    assigns = %{
      client_name: validated.client.client_name,
      client_id: validated.client.id,
      redirect_uri: validated.redirect_uri,
      code_challenge: validated.code_challenge,
      scope: validated.scope,
      state: validated.state,
      resource: validated.resource,
      action_path: conn.request_path,
      csrf_token: get_csrf_token(),
      consent_request: mint_consent_request(server!(opts), validated)
    }

    body = view.render(:consent, assigns) |> IO.iodata_to_binary()

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("content-security-policy", "frame-ancestors 'none'")
    |> send_resp(200, body)
    |> halt()
  end

  defp sign_in_redirect(conn, server) do
    case server.sign_in_path() do
      path when is_binary(path) ->
        return_to =
          conn.request_path <>
            if conn.query_string != "", do: "?" <> conn.query_string, else: ""

        # AshAuthentication.Phoenix sign-in handlers read `:return_to` from
        # session, not from the query string. Put it in both so any
        # convention works.
        conn
        |> Plug.Conn.put_session(:return_to, return_to)
        |> put_resp_header(
          "location",
          path <> "?" <> URI.encode_query(%{"return_to" => return_to})
        )
        |> send_resp(302, "")
        |> halt()

      _ ->
        conn |> send_resp(401, "authentication required") |> halt()
    end
  end

  # sobelow_skip ["XSS.SendResp"]
  defp bad_redirect_html(conn) do
    body = """
    <!DOCTYPE html>
    <html lang="en"><head><meta charset="UTF-8"><title>Invalid redirect URI</title>
    <style>body{font-family:system-ui,sans-serif;max-width:480px;margin:4rem auto;padding:0 1rem}</style>
    </head><body><h1>Invalid redirect URI</h1>
    <p>The <code>redirect_uri</code> does not match any registered redirect URI for this client.</p>
    <p>For security reasons, we cannot redirect you back. Please contact the application that sent you here.</p>
    </body></html>
    """

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(400, body)
    |> halt()
  end

  # sobelow_skip ["XSS.SendResp"]
  defp bad_state_html(conn) do
    body = """
    <!DOCTYPE html>
    <html lang="en"><head><meta charset="UTF-8"><title>Request too large</title>
    <style>body{font-family:system-ui,sans-serif;max-width:480px;margin:4rem auto;padding:0 1rem}</style>
    </head><body><h1>Request too large</h1>
    <p>The <code>state</code> parameter exceeds the maximum permitted size.</p>
    </body></html>
    """

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(400, body)
    |> halt()
  end

  defp get_csrf_token do
    Plug.CSRFProtection.get_csrf_token()
  rescue
    _ -> ""
  end

  # Bind the user-visible consent UI to the values that drove the code
  # issuance. The token captures everything an attacker might want to
  # silently swap (scope, code_challenge, redirect_uri, state, resource,
  # client_id) and is verified before the POST is honoured.
  defp mint_consent_request(server, validated) do
    payload = %{
      "client_id" => validated.client.id,
      "redirect_uri" => validated.redirect_uri,
      "code_challenge" => validated.code_challenge,
      "scope" => validated.scope,
      "state" => validated.state,
      "resource" => validated.resource
    }

    Plug.Crypto.sign(server.signing_secret(), @consent_request_salt, payload)
  end

  defp verify_consent_request(server, token) when is_binary(token) and token != "" do
    case Plug.Crypto.verify(server.signing_secret(), @consent_request_salt, token,
           max_age: @consent_request_max_age
         ) do
      {:ok, payload} when is_map(payload) -> {:ok, payload}
      _ -> {:error, :invalid}
    end
  end

  defp verify_consent_request(_server, _token), do: {:error, :invalid}

  # Rebuild the protocol params from the sealed payload so `validate_request`
  # operates on trusted server-side values, not the form's hidden inputs.
  defp sealed_params(sealed) do
    %{
      "response_type" => "code",
      "code_challenge_method" => "S256",
      "client_id" => Map.get(sealed, "client_id"),
      "redirect_uri" => Map.get(sealed, "redirect_uri"),
      "code_challenge" => Map.get(sealed, "code_challenge"),
      "scope" => Map.get(sealed, "scope"),
      "state" => Map.get(sealed, "state"),
      "resource" => Map.get(sealed, "resource")
    }
  end
end
