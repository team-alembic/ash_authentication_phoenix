defmodule AshAuthentication.Phoenix.Overrides.Overridable do
  @moduledoc """
  Auto generates documentation and helpers for components.
  """

  alias AshAuthentication.Phoenix.Overrides

  @callback __overrides__ :: %{required(atom) => binary}

  @doc false
  @spec __using__(keyword) :: Macro.t()
  defmacro __using__(opts) do
    overrides =
      opts
      |> Enum.filter(fn
        {name, value} when is_atom(name) and is_binary(value) -> true
        _ -> false
      end)
      |> Map.new()
      |> Macro.escape()

    quote generated: true do
      @behaviour unquote(__MODULE__)
      require Overrides
      require Overrides.Overridable
      @overrides unquote(overrides)
      import Overrides.Overridable, only: :macros

      @doc false
      @impl true
      @spec __overrides__ :: %{required(atom) => binary}
      def __overrides__ do
        unquote(overrides)
      end

      defoverridable __overrides__: 0
    end
  end

  @doc false
  @spec generate_docs :: Macro.t()
  defmacro generate_docs do
    quote do
      """
      ## Overrides

      This component provides the following overrides:

      #{@overrides |> Enum.map(&"  * `#{inspect(elem(&1, 0))}` - #{elem(&1, 1)}\n")}

      See `AshAuthentication.Phoenix.Overrides` for more information.
      """
    end
  end

  @doc """
  Retrieve configuration for a potentially overriden value.
  """
  @spec override_for([module], atom, any) :: any
  defmacro override_for(overrides, selector, default \\ nil) do
    component = __CALLER__.module
    component_overrides = Module.get_attribute(component, :overrides, %{})

    if Map.has_key?(component_overrides, selector) do
      quote do
        override =
          unquote(overrides)
          |> Enum.reduce_while(nil, fn module, _ ->
            module.overrides()
            |> Map.fetch({unquote(component), unquote(selector)})
            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            |> case do
              {:ok, value} -> {:halt, value}
              :error -> {:cont, nil}
            end
          end)

        override || unquote(default)
      end
    else
      IO.warn(
        "Unknown override `#{inspect(selector)}` in component `#{inspect(__CALLER__.module)}"
      )

      quote do
        unquote(default)
      end
    end
  end
end
