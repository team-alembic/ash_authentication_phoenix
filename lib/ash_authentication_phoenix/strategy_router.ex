# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.StrategyRouter do
  @moduledoc false
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    # ensure query params have been fetched
    conn = Plug.Conn.fetch_query_params(conn)

    opts
    |> routes()
    |> Enum.reduce_while(
      {:not_found, conn},
      fn {resource, strategy, path, phase}, {:not_found, conn} ->
        strategy_path_split = Path.split(String.trim_leading(path, "/"))

        if paths_match?(strategy_path_split, conn.path_info) &&
             conn.method ==
               String.upcase(
                 to_string(AshAuthentication.Strategy.method_for_phase(strategy, phase))
               ) do
          {:halt, {:found, resource, strategy, path, phase}}
        else
          {:cont, {:not_found, conn}}
        end
      end
    )
    |> case do
      {:found, resource, strategy, _path, phase} ->
        subject_name = AshAuthentication.Info.authentication_subject_name!(resource)

        conn
        |> Plug.Conn.put_private(:strategy, strategy)
        |> opts[:controller].call(
          {subject_name, AshAuthentication.Strategy.name(strategy), phase}
        )

      {:not_found, conn} ->
        not_found(conn, opts)
    end
  end

  if Code.ensure_loaded?(Phoenix.Router) &&
       function_exported?(Phoenix.Router, :__formatted_routes__, 1) do
    @behaviour Phoenix.VerifiedRoutes

    alias AshAuthentication.Phoenix.StrategyRouter

    @impl Phoenix.VerifiedRoutes
    def formatted_routes(opts) do
      StrategyRouter.__formatted_routes__(opts)
    end

    @impl Phoenix.VerifiedRoutes
    def verified_route?(opts, path) do
      StrategyRouter.__verified_route__?(opts, path)
    end
  end

  defp not_found(conn, opts) do
    if plug = opts[:not_found_plug] do
      plug.call(conn, opts)
    else
      conn
      |> Plug.Conn.put_status(:not_found)
      |> Phoenix.Controller.json(%{error: "Not Found"})
      |> Plug.Conn.halt()
    end
  end

  defp paths_match?([], []), do: true

  defp paths_match?([":" <> _ | strategy_rest], [_ | actual_rest]) do
    paths_match?(strategy_rest, actual_rest)
  end

  defp paths_match?([":*"], _), do: true

  defp paths_match?([item | strategy_rest], [item | actual_rest]) do
    paths_match?(strategy_rest, actual_rest)
  end

  defp paths_match?(_, _), do: false

  defp routes(opts) do
    opts[:resources]
    |> Stream.flat_map(fn resource ->
      resource
      |> AshAuthentication.Info.authentication_add_ons()
      |> Enum.concat(AshAuthentication.Info.authentication_strategies(resource))
      |> Stream.flat_map(&strategy_routes(resource, &1))
    end)
  end

  defp strategy_routes(resource, strategy) do
    strategy
    |> AshAuthentication.Strategy.routes()
    |> Stream.map(fn {path, phase} ->
      {resource, strategy, path, phase}
    end)
  end

  @doc false
  def __formatted_routes__(opts) do
    opts
    |> routes()
    |> Enum.map(fn {resource, strategy, path, phase} ->
      %{
        verb:
          String.upcase(to_string(AshAuthentication.Strategy.method_for_phase(strategy, phase))),
        path: path,
        label: "#{inspect(resource)}.#{strategy.name} #{inspect(phase)}"
      }
    end)
  end

  @doc false
  def __verified_route__?(opts, path) do
    opts
    |> routes()
    |> Enum.map(&elem(&1, 2))
    |> Enum.map(fn route ->
      case Path.split(route) do
        ["/" | rest] -> rest
        path -> path
      end
    end)
    |> Enum.any?(&match_path?(&1, path))
  end

  defp match_path?([], []), do: true
  defp match_path?([], _), do: false
  defp match_path?(_, []), do: false

  defp match_path?([":" <> _ | rest_route], [_ | rest_path]) do
    match_path?(rest_route, rest_path)
  end

  defp match_path?(["_" <> _ | rest_route], [_ | rest_path]) do
    match_path?(rest_route, rest_path)
  end

  defp match_path?(["*" <> _], _) do
    true
  end

  defp match_path?([same | rest_path], [same | rest_route]) do
    match_path?(rest_path, rest_route)
  end

  defp match_path?(_, _) do
    false
  end
end
