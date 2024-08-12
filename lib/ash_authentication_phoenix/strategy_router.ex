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

        if paths_match?(strategy_path_split, conn.path_info) do
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
end
