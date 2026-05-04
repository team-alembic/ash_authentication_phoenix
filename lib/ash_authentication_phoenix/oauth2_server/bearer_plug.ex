# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Oauth2Server.BearerPlug do
  @moduledoc """
  Resource-server side bearer token validation.

  Validates an `Authorization: Bearer <jwt>` header against the configured
  authorization server. On success, loads the user via `Ash.get/3` on the
  configured `user_resource` and sets it as the conn's actor.

  ## Usage

      pipeline :mcp_protected do
        plug AshAuthentication.Phoenix.Oauth2Server.BearerPlug,
          oauth2_server: MyApp.Oauth2Server
      end

  ## Options

    * `:oauth2_server` (required) — your `Oauth2Server` config module
    * `:required?` (default `true`) — when `false`, missing/invalid tokens
      pass through unchanged instead of returning 401. Useful for routes
      that should serve unauthenticated users with a different (e.g.
      session-based) signal.

  ## Failure behavior

  Per RFC 6750 §3, a missing or invalid token results in `401` with a
  `WWW-Authenticate: Bearer resource_metadata="..."` header pointing at
  the protected-resource metadata endpoint, so MCP-style clients can
  auto-discover the authorization server.
  """

  @behaviour Plug
  import Plug.Conn

  alias AshAuthentication.Oauth2Server.Jwt

  @impl Plug
  def init(opts) do
    %{
      server: Keyword.fetch!(opts, :oauth2_server),
      required?: Keyword.get(opts, :required?, true)
    }
  end

  @impl Plug
  def call(conn, %{server: server, required?: required?}) do
    case extract_token(conn) do
      :no_token when required? ->
        challenge(conn, server, nil)

      :no_token ->
        conn

      {:ok, token} ->
        case verify_and_load(server, token) do
          {:ok, user, claims} ->
            conn
            |> Ash.PlugHelpers.set_actor(user)
            |> assign(:oauth_claims, claims)

          {:error, reason} when required? ->
            challenge(conn, server, reason)

          {:error, _} ->
            conn
        end
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token | _] when token != "" -> {:ok, token}
      ["bearer " <> token | _] when token != "" -> {:ok, token}
      _ -> :no_token
    end
  end

  defp verify_and_load(server, token) do
    with {:ok, claims} <- Jwt.verify(server, token),
         {:ok, user} <- load_user(server, claims) do
      {:ok, user, claims}
    end
  end

  defp load_user(server, %{"sub" => sub}) when is_binary(sub) and sub != "" do
    case Ash.get(server.user_resource(), sub, authorize?: false) do
      {:ok, user} -> {:ok, user}
      _ -> {:error, :user_not_found}
    end
  end

  defp load_user(_, _), do: {:error, :missing_subject}

  defp challenge(conn, server, reason) do
    metadata_url = server.resource_url() <> "/.well-known/oauth-protected-resource"

    error_param =
      case reason do
        nil -> ""
        :invalid_audience -> ~s|, error="invalid_token", error_description="audience mismatch"|
        :invalid_issuer -> ~s|, error="invalid_token", error_description="issuer mismatch"|
        :expired -> ~s|, error="invalid_token", error_description="token expired"|
        _ -> ~s|, error="invalid_token"|
      end

    conn
    |> put_resp_header(
      "www-authenticate",
      ~s|Bearer resource_metadata="#{metadata_url}"#{error_param}|
    )
    |> send_resp(401, "")
    |> halt()
  end
end
