# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Oauth2Server.ProtocolRouter do
  @moduledoc """
  Plug router for the client-facing OAuth 2.1 protocol endpoints — anything
  called by an external OAuth client without a browser session.

  Endpoints handled:

    * `GET /oauth-authorization-server` — RFC 8414 metadata
    * `GET /oauth-protected-resource`   — RFC 9728 metadata
    * `GET /openid-configuration`       — alias for OIDC-conformant tooling
    * `POST /register`                  — RFC 7591 Dynamic Client Registration
    * `POST /token`                     — authorization_code + refresh_token grants

  Mount this behind your API pipeline (no CSRF, no session needed). For the
  human-driven consent step (`/authorize`), see
  `AshAuthentication.Phoenix.Oauth2Server.ConsentRouter`.

  ## Options

    * `:oauth2_server` (required) — the user's `Oauth2Server` config module
  """

  use Plug.Router, copy_opts_to_assign: :oauth2_server_router_opts

  alias AshAuthentication.Oauth2Server.{Metadata, Register, Token}
  alias AshAuthentication.Phoenix.Oauth2Server.Errors

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug :match
  plug :dispatch

  # ── metadata ───────────────────────────────────────────────────────────────

  get "/oauth-authorization-server", do: serve_authorization_server_metadata(conn)
  get "/openid-configuration", do: serve_authorization_server_metadata(conn)

  get "/oauth-protected-resource" do
    server = server!(conn.assigns.oauth2_server_router_opts)

    conn
    |> put_resp_header("content-type", "application/json")
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(200, Jason.encode!(Metadata.protected_resource(server)))
    |> halt()
  end

  # ── DCR ────────────────────────────────────────────────────────────────────

  post "/register" do
    server = server!(conn.assigns.oauth2_server_router_opts)

    case Register.register(server, conn.params) do
      {:ok, _client, body} ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> put_resp_header("cache-control", "no-store")
        |> send_resp(201, Jason.encode!(body))
        |> halt()

      {:error, code, desc} ->
        Errors.send_dcr_error(conn, code, desc)
    end
  end

  # ── token ──────────────────────────────────────────────────────────────────

  post "/token" do
    server = server!(conn.assigns.oauth2_server_router_opts)
    params = conn.params || %{}

    result =
      case Map.get(params, "grant_type") do
        "authorization_code" -> Token.exchange_authorization_code(server, params)
        "refresh_token" -> Token.exchange_refresh_token(server, params)
        _ -> {:error, :unsupported_grant_type}
      end

    case result do
      {:ok, response} ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> put_resp_header("cache-control", "no-store")
        |> send_resp(200, Jason.encode!(token_response_json(response)))
        |> halt()

      {:error, :unsupported_grant_type} ->
        Errors.send_oauth_error(conn, 400, "unsupported_grant_type", nil)

      {:error, reason} ->
        {status, code, desc} = Errors.describe_token_error(reason)
        Errors.send_oauth_error(conn, status, code, desc)
    end
  end

  # ── default ────────────────────────────────────────────────────────────────

  match _ do
    conn |> send_resp(404, "") |> halt()
  end

  # ── helpers ───────────────────────────────────────────────────────────────

  defp server!(opts), do: Keyword.fetch!(opts, :oauth2_server)

  defp serve_authorization_server_metadata(conn) do
    server = server!(conn.assigns.oauth2_server_router_opts)

    conn
    |> put_resp_header("content-type", "application/json")
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(200, Jason.encode!(Metadata.authorization_server(server)))
    |> halt()
  end

  defp token_response_json(%{} = response) do
    %{
      "access_token" => response.access_token,
      "token_type" => response.token_type,
      "expires_in" => response.expires_in,
      "refresh_token" => response.refresh_token,
      "scope" => response.scope
    }
  end
end
