# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Router.OnLiveViewMount do
  @moduledoc false
  import Phoenix.Component

  @doc false
  def on_mount(:default, _params, %{"otp_app" => otp_app}, socket) when not is_nil(otp_app) do
    {:cont, assign(socket, :otp_app, otp_app)}
  end

  def on_mount(_, _params, _session, socket), do: {:cont, socket}
end
