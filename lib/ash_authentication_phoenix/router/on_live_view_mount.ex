# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Router.OnLiveViewMount do
  @moduledoc false
  import Phoenix.Component

  @doc false
  def on_mount(action, _params, session, socket) do
    case {action, session} do
      {:default, %{"otp_app" => otp_app}} when not is_nil(otp_app) ->
        {:cont, assign(socket, :otp_app, otp_app)}

      _ ->
        {:cont, socket}
    end
  end
end
