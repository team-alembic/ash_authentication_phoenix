defmodule AshAuthentication.Phoenix.Router.ConsoleFormatter do
  @moduledoc false

  @doc """
  Format the routes for printing.

  This was copied from Phoenix and adapted for our case.
  """
  def format(router, endpoint \\ nil) do
    routes = Phoenix.Router.routes(router)
    column_widths = calculate_column_widths(router, routes, endpoint)

    routes
    |> Enum.map(&format_route(&1, router, column_widths))
    |> Enum.filter(& &1)
    |> Enum.join("")
  end

  defp calculate_column_widths(router, routes, endpoint) do
    sockets = (endpoint && endpoint.__sockets__()) || []

    widths =
      Enum.reduce(routes, {0, 0, 0}, fn route, acc ->
        %{verb: verb, path: path, helper: helper} = route
        verb = verb_name(verb)
        {verb_len, path_len, route_name_len} = acc
        route_name = route_name(router, helper)

        {max(verb_len, String.length(verb)), max(path_len, String.length(path)),
         max(route_name_len, String.length(route_name))}
      end)

    Enum.reduce(sockets, widths, fn {path, _mod, _opts}, acc ->
      {verb_len, path_len, route_name_len} = acc
      prefix = if router.__helpers__(), do: "websocket", else: ""

      {verb_len, max(path_len, String.length(path <> "/websocket")),
       max(route_name_len, String.length(prefix))}
    end)
  end

  defp format_route(
         %{
           verb: :*,
           plug: AshAuthentication.Phoenix.StrategyRouter,
           path: plug_path,
           plug_opts: plug_opts,
           helper: helper
         },
         router,
         column_widths
       ) do
    plug_opts[:resources]
    |> List.wrap()
    |> resource_routes()
    |> Enum.map(fn {strategy, path, phase} ->
      verb = verb_name(AshAuthentication.Strategy.method_for_phase(strategy, phase))
      route_name = route_name(router, helper)
      {verb_len, path_len, route_name_len} = column_widths
      log_module = strategy.__struct__
      path = Path.join(plug_path || "/", path)

      String.pad_leading(route_name, route_name_len) <>
        "  " <>
        String.pad_trailing(verb, verb_len) <>
        "  " <>
        String.pad_trailing(path, path_len) <>
        "  " <>
        "#{inspect(log_module)}\n"
    end)
  end

  defp format_route(_, _, _), do: nil

  defp resource_routes(resources) do
    Stream.flat_map(resources, fn resource ->
      resource
      |> AshAuthentication.Info.authentication_add_ons()
      |> Enum.concat(AshAuthentication.Info.authentication_strategies(resource))
      |> strategy_routes()
    end)
  end

  defp strategy_routes(strategies) do
    Stream.flat_map(strategies, fn strategy ->
      strategy
      |> AshAuthentication.Strategy.routes()
      |> Stream.map(fn {path, phase} -> {strategy, path, phase} end)
    end)
  end

  defp route_name(_router, nil), do: ""

  defp route_name(router, name) do
    if router.__helpers__() do
      name <> "_path"
    else
      ""
    end
  end

  defp verb_name(verb), do: verb |> to_string() |> String.upcase()
end
