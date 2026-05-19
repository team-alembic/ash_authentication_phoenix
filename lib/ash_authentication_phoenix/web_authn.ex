# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.WebAuthn do
  @moduledoc """
  Helpers shared between the WebAuthn LiveView components.
  """

  @doc """
  Build a WebAuthn origin string from the LiveView socket's `host_uri`.

  Used to override the strategy's configured origin with the actual request
  origin during a ceremony, so dev/test environments don't need a hardcoded
  port baked into config.
  """
  @spec origin_from_socket(Phoenix.LiveView.Socket.t()) :: String.t()
  def origin_from_socket(%Phoenix.LiveView.Socket{host_uri: %URI{} = uri}),
    do: uri_to_origin(uri)

  defp uri_to_origin(%URI{scheme: scheme, host: host, port: port}) do
    port_segment =
      cond do
        scheme == "http" and port == 80 -> ""
        scheme == "https" and port == 443 -> ""
        is_nil(port) -> ""
        true -> ":#{port}"
      end

    "#{scheme}://#{host}#{port_segment}"
  end
end
