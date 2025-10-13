# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Helpers do
  @moduledoc """
  Helpers which are commonly needed inside the various components.
  """
  alias Ash.Resource.Info
  alias AshAuthentication.{Strategy, Strategy.RememberMe}
  alias Phoenix.LiveView.Socket
  require Logger

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
      |> set_query(params)
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

  defp set_query(uri, params) do
    if params && params != %{} do
      Map.put(uri, :query, URI.encode_query(params))
    else
      uri
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

  @doc """
  Returns the name of the remember me field name if any for the given strategy.
  It does this by looking for the  presence of `RememberMe.MaybeGenerateTokenPreparation`
  and the name of the argument that it is expecting.
  """
  @spec remember_me_field(Strategy.t()) :: atom | nil
  def remember_me_field(strategy) do
    with sign_in_action when not is_nil(sign_in_action) <-
           Info.action(strategy.resource, strategy.sign_in_action_name),
         prep_opts when not is_nil(prep_opts) <-
           Enum.find_value(sign_in_action.preparations, fn
             %Ash.Resource.Preparation{
               preparation: {RememberMe.MaybeGenerateTokenPreparation, opts}
             } ->
               opts

             _ ->
               nil
           end) do
      Keyword.get(prep_opts, :arguments, :remember_me)
    else
      _ -> nil
    end
  end

  @doc """
  Logs all form errors when `debug_authentication_failures?` is configured to `true`
  """
  def debug_form_errors(form) do
    if Application.get_env(:ash_authentication, :debug_authentication_failures?) do
      log =
        form
        |> AshPhoenix.Form.raw_errors(for_path: :all)
        |> Enum.sort_by(&length(elem(&1, 0)))
        |> Enum.map_join(&format_error_with_path/1)

      Logger.warning(
        "Encountered errors when submitting form for #{inspect(form.source.resource)}#{form.source.action.name}\n\n#{log}"
      )
    end

    form
  end

  defp format_error_with_path({path, error}) do
    prefix =
      if path == [] do
        "Errors:\n\n"
      else
        "Errors for path #{inspect(path)}:\n\n"
      end

    prefix <>
      Enum.map_join(error, fn error ->
        Exception.format(:error, error, stacktrace(error))
        |> String.split("\n")
        |> Enum.map_join("\n", &"  #{&1}")
      end)
  end

  defp stacktrace(%{stacktrace: %{stacktrace: stacktrace}}) do
    stacktrace
  end

  defp stacktrace(_error) do
    nil
  end
end
