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

  @doc """
  Find the override for a specific element.

  Uses `otp_app_from_socket/1` to find the OTP application name and then extract
  the configuration from the application environment.
  """
  @spec override_for(Socket.t(), atom) :: nil | String.t()
  def override_for(socket, name) do
    module =
      socket
      |> otp_app_from_socket()
      |> Application.get_env(AshAuthentication.Phoenix, [])
      |> Keyword.get(:override_module, AshAuthentication.Phoenix.Overrides.Default)

    apply(module, name, [])
  end
end
