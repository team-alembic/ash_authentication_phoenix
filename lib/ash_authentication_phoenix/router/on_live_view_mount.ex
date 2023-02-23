defmodule AshAuthenticationPhoenix.Router.OnLiveViewMount do
  @moduledoc false
  import Phoenix.Component

  @spec on_mount(atom, %{required(String.t()) => any}, %{required(String.t()) => any}, Socket.t()) ::
          {:cont | :halt, Socket.t()}
  def on_mount(:default, _params, %{"otp_app" => otp_app}, socket) when not is_nil(otp_app) do
    asign(socket, :otp_app, otp_app)
    {:cont, socket}
  end

  def on_mount(_, _params, _session, socket), do: {:cont, socket}
end
