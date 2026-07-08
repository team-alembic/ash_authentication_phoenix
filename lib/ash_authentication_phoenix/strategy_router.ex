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

        with {:match, bindings} <- match_path(strategy_path_split, conn.path_info, %{}),
             true <- conn.method in methods_for_phase(strategy, phase) do
          {:halt, {:found, resource, strategy, path, phase, bindings}}
        else
          _ -> {:cont, {:not_found, conn}}
        end
      end
    )
    |> case do
      {:found, resource, strategy, _path, phase, bindings} ->
        subject_name = AshAuthentication.Info.authentication_subject_name!(resource)

        conn
        |> merge_path_bindings(bindings)
        |> Plug.Conn.put_private(:strategy, strategy)
        |> opts[:controller].call(
          {subject_name, AshAuthentication.Strategy.name(strategy), phase}
        )

      {:not_found, conn} ->
        not_found(conn, opts)
    end
  end

  # A phase may accept more than one HTTP method (e.g. the OAuth2/OIDC callback
  # accepts GET and POST, the latter for `response_mode=form_post` providers).
  defp methods_for_phase(strategy, phase) do
    strategy
    |> AshAuthentication.Strategy.method_for_phase(phase)
    |> List.wrap()
    |> Enum.map(&String.upcase(to_string(&1)))
  end

  defp merge_path_bindings(conn, bindings) when bindings == %{}, do: conn

  defp merge_path_bindings(conn, bindings) do
    path_params = Map.merge(conn.path_params, bindings)

    params =
      case conn.params do
        %Plug.Conn.Unfetched{} -> conn.params
        params -> Map.merge(params, bindings)
      end

    %{conn | path_params: path_params, params: params}
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

  defp match_path([], [], bindings), do: {:match, bindings}

  defp match_path([":*"], _, bindings), do: {:match, bindings}

  defp match_path([":" <> name | strategy_rest], [value | actual_rest], bindings) do
    match_path(strategy_rest, actual_rest, Map.put(bindings, name, value))
  end

  defp match_path([item | strategy_rest], [item | actual_rest], bindings) do
    match_path(strategy_rest, actual_rest, bindings)
  end

  defp match_path(_, _, _), do: :no_match

  defp routes(opts) do
    opts[:resources]
    |> Stream.flat_map(fn resource ->
      resource
      |> AshAuthentication.Info.authentication_add_ons()
      |> Enum.concat(AshAuthentication.Info.authentication_strategies(resource))
      |> filter_strategies_and_addons(opts)
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
  def filter_strategies_and_addons(strategies_and_addons, opts) do
    cond do
      only = opts[:only] ->
        Enum.filter(strategies_and_addons, fn item ->
          item.name in only
        end)

      except = opts[:except] ->
        Enum.reject(strategies_and_addons, fn item ->
          item.name in except
        end)

      true ->
        strategies_and_addons
    end
  end

  @doc false
  def __formatted_routes__(opts) do
    opts
    |> routes()
    |> Enum.flat_map(fn {resource, strategy, path, phase} ->
      strategy
      |> AshAuthentication.Strategy.method_for_phase(phase)
      |> List.wrap()
      |> Enum.map(fn method ->
        %{
          verb: String.upcase(to_string(method)),
          path: path,
          label: "#{inspect(resource)}.#{strategy.name} #{inspect(phase)}"
        }
      end)
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
