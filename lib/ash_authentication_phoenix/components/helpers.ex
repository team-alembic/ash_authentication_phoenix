defmodule AshAuthentication.Phoenix.Components.Helpers do
  @moduledoc """
  Helpers which are commonly needed inside the various components.
  """
  alias Phoenix.LiveView.Socket

  @doc """
  The LiveView `Socket` contains a reference to the Phoenix endpoint, and from
  there we can extract the `otp_app` of the current request.

  This is pulled from `assigns[:otp_app]`, or inferred
  from the socket if that is not set.
  """
  @spec otp_app_from_socket(Socket.t()) :: atom
  def otp_app_from_socket(socket) do
    socket.assigns[:otp_app] ||
      :otp_app
      |> socket.endpoint.config()
  end

  def auth_path(socket, subject_name, auth_routes_prefix, strategy, phase, params \\ %{}) do
    if auth_routes_prefix do
      strategy
      |> AshAuthentication.Strategy.routes()
      |> Enum.find(&(elem(&1, 1) == phase))
      |> elem(0)
      |> URI.parse()
      |> Map.put(:query, URI.encode_query(params))
      |> Map.update!(:path, &Path.join(auth_routes_prefix, &1))
      |> URI.to_string()
    else
      route_helpers = route_helpers(socket)

      if Code.ensure_loaded?(route_helpers) do
        route_helpers.auth_path(
          socket.endpoint,
          {subject_name, AshAuthentication.Strategy.name(strategy), phase},
          params
        )
      else
        raise """
        Must configure the `auth_routes_prefix`, or enable router helpers.
        """
      end
    end
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
