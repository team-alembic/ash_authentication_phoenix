defmodule AshAuthentication.Phoenix.Components.Helpers do
  @moduledoc """
  Helpers which are commonly needed inside the various components.
  """
  alias Phoenix.LiveView.Socket

  @doc """
  The LiveView `Socket` contains a reference to the Phoenix endpoint, and from
  there we can extract the `otp_app` of the current request.
  """
  @spec otp_app_from_socket(Socket.t()) :: atom
  def otp_app_from_socket(socket) do
    :otp_app
    |> socket.endpoint.config()
  end

  @doc """
  The LiveView `Socket` contains a refererence to the Phoenix router, and from
  there we can generate the name of the route helpers module.
  """
  @spec route_helpers(Socket.t()) :: module
  def route_helpers(socket) do
    Module.concat(socket.router, Helpers)
  end
end
