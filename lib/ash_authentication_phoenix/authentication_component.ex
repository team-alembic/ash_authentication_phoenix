defmodule AshAuthentication.Phoenix.AuthenticationComponent do
  @moduledoc """
  A basic behaviour to help us lay our components out on the screen.

  ## Usage

  ```elixir
  defmodule MyComponent do
    use AshAuthentication.Phoenix.AuthenticationComponent, style: :link
  end
  ```

  We have two "styles" of component, `:form` and `:link`, which defines how they
  should be rendered before or after the "or" divider.

  You will need to implement this if you're using
  `AshAuthentication.Phoenix.Components.SignIn` for your component to be
  visible.  You can ignore if it you're not.
  """

  @doc """
  Is the component a `:link` style?

  Auto-generated, but overridable.
  """
  @callback link? :: boolean

  @doc """
  Is the component a `:form` style?

  Auto-generated, but overridable.
  """
  @callback form? :: boolean

  @type options :: [{:style, :link | :form}]

  @doc false
  @spec __using__(options) :: Macro.t()
  defmacro __using__(opts) do
    style = Keyword.get(opts, :style)

    quote do
      @behaviour AshAuthentication.Phoenix.AuthenticationComponent

      @doc false
      @spec link? :: boolean
      def link?, do: unquote(style == :link)

      @doc false
      @spec form? :: boolean
      def form?, do: unquote(style == :form)
    end
  end
end
