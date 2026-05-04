# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Oauth2Server.Errors do
  @moduledoc """
  HTTP error response helpers for OAuth 2.1 / RFC 7591.
  """

  import Plug.Conn

  @doc """
  Send a JSON error per OAuth 2.0 / RFC 6749 §5.2.

  Codes: `"invalid_request"`, `"invalid_client"`, `"invalid_grant"`,
  `"unsupported_grant_type"`, `"invalid_scope"`, etc.
  """
  @spec send_oauth_error(Plug.Conn.t(), pos_integer(), String.t(), String.t() | nil) ::
          Plug.Conn.t()
  def send_oauth_error(conn, status, code, description \\ nil) do
    body = %{"error" => code} |> maybe_put("error_description", description)

    conn
    |> put_resp_header("content-type", "application/json")
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(status, Jason.encode!(body))
    |> halt()
  end

  @doc """
  Send a 400 with an RFC 7591 DCR-shaped error.

  Codes: `"invalid_redirect_uri"`, `"invalid_client_metadata"`.
  """
  def send_dcr_error(conn, code, description \\ nil) do
    send_oauth_error(conn, 400, code, description)
  end

  @doc """
  Translate a `:reason` atom returned from a core module into an
  `{http_status, error_code, description}` triple suitable for an OAuth
  error response.
  """
  @spec describe_token_error(atom()) :: {pos_integer(), String.t(), String.t()}
  def describe_token_error(reason) do
    case reason do
      :reuse -> {400, "invalid_grant", "code or refresh token already used"}
      :expired -> {400, "invalid_grant", "expired"}
      :pkce -> {400, "invalid_grant", "PKCE verification failed"}
      :resource_mismatch -> {400, "invalid_grant", "resource does not match"}
      :redirect_mismatch -> {400, "invalid_grant", "redirect_uri mismatch"}
      :invalid_code -> {400, "invalid_grant", "code not found or invalid"}
      :invalid_refresh -> {400, "invalid_grant", "refresh token invalid"}
      :revoked -> {400, "invalid_grant", "refresh token revoked"}
      :client_mismatch -> {400, "invalid_grant", "client mismatch"}
      :invalid_request -> {400, "invalid_request", "missing required parameters"}
      :refresh_create_failed -> {500, "server_error", "could not issue refresh token"}
      _ -> {400, "invalid_request", "request could not be processed"}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
