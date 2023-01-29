defmodule AshAuthentication.Phoenix.StrategyComponent do
  @callback __visual_style__ :: :form | :link
  @callback __strategies__ :: [module]

  defmacro __using__(opts) do
    visual_style = Keyword.get(opts, :visual_style, :form)
    strategies = Keyword.get(opts, :strategies, [])

    quote generated: true do
      @behaviour unquote(__MODULE__)
      @after_verify unquote(__MODULE__)

      def __visual_style__, do: unquote(visual_style)
      def __strategies__, do: unquote(strategies)

      defoverridable __visual_style__: 0, __strategies__: 0
    end
  end

  def __after_verify__(module) do
    visual_style = module.__visual_style__()

    unless visual_style in ~w[form link]a do
      IO.warn(
        "Strategy component `#{inspect(module)}` has visual style of `#{inspect(visual_style)}`, must be one of `:link` or `:form`."
      )
    end

    if Enum.empty?(module.__strategies__()) do
      IO.warn(
        "Strategy component`#{inspect(module)}` doesn't specify any strategies that it supports."
      )
    end

    :ok
  end
end
