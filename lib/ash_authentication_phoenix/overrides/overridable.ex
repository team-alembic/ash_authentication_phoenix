defmodule AshAuthentication.Phoenix.Overrides.Overridable do
  @moduledoc """
  Auto generates documentation and helpers for components.
  """

  alias AshAuthentication.Phoenix.{Components.Helpers, Overrides}
  alias Phoenix.LiveView.Socket

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

    quote do
      require AshAuthentication.Phoenix.Overrides
      require AshAuthentication.Phoenix.Overrides.Overridable
      @overrides unquote(overrides)
      import AshAuthentication.Phoenix.Overrides.Overridable, only: :macros
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
  @spec override_for(Socket.t(), atom, any) :: any
  defmacro override_for(socket, selector, default \\ nil) do
    overrides =
      __CALLER__.module
      |> Module.get_attribute(:overrides, %{})

    if Map.has_key?(overrides, selector) do
      quote do
        override =
          unquote(socket)
          |> Helpers.otp_app_from_socket()
          |> Overrides.override_for(__MODULE__, unquote(selector))

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
