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

  alias AshAuthentication.Oauth2Server.Authorize
  alias AshAuthentication.Phoenix.Oauth2Server.{ConsentView, Errors}

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

    with {:ok, validated} <- Authorize.validate_request(server, params),
         {:ok, user} <- require_user(conn) do
      if Authorize.consented?(server, user, validated.client, validated.scope) do
        issue_code_redirect(conn, server, user, validated)
      else
        render_consent(conn, validated, opts)
      end
    else
      {:error, :no_user} -> sign_in_redirect(conn, server)
      {:error, :bad_redirect_uri} -> bad_redirect_html(conn)
      {:error, code, desc} -> Errors.send_oauth_error(conn, 400, code, desc)
    end
  end

  defp handle_post(conn, server) do
    params = conn.params

    with {:ok, validated} <- Authorize.validate_request(server, params),
         {:ok, user} <- require_user(conn) do
      case Map.get(params, "action") do
        "approve" ->
          Authorize.grant_consent!(server, user, validated.client, validated.scope)
          issue_code_redirect(conn, server, user, validated)

        "deny" ->
          redirect_with_error(conn, validated, "access_denied")

        _ ->
          Errors.send_oauth_error(conn, 400, "invalid_request", "missing action")
      end
    else
      {:error, :no_user} -> sign_in_redirect(conn, server)
      {:error, :bad_redirect_uri} -> bad_redirect_html(conn)
      {:error, code, desc} -> Errors.send_oauth_error(conn, 400, code, desc)
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

  defp redirect_with_error(conn, validated, error) do
    location =
      validated.redirect_uri <>
        "?" <> URI.encode_query(%{"error" => error, "state" => validated.state})

    conn
    |> put_resp_header("location", location)
    |> send_resp(302, "")
    |> halt()
  end

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
      csrf_token: get_csrf_token()
    }

    body = view.render(:consent, assigns) |> IO.iodata_to_binary()

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> put_resp_header("x-frame-options", "DENY")
    |> send_resp(200, body)
    |> halt()
  end

  defp sign_in_redirect(conn, server) do
    case server.sign_in_path() do
      path when is_binary(path) ->
        return_to =
          conn.request_path <>
            if conn.query_string != "", do: "?" <> conn.query_string, else: ""

        location = path <> "?" <> URI.encode_query(%{"return_to" => return_to})

        conn
        |> put_resp_header("location", location)
        |> send_resp(302, "")
        |> halt()

      _ ->
        conn |> send_resp(401, "authentication required") |> halt()
    end
  end

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

  defp get_csrf_token do
    Plug.CSRFProtection.get_csrf_token()
  rescue
    _ -> ""
  end
end
