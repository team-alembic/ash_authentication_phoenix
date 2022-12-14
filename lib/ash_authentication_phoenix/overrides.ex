defmodule AshAuthentication.Phoenix.Overrides do
  @moduledoc """
  Behaviour for overriding component styles and attributes in your application.

  The default implementation is `AshAuthentication.Phoenix.Overrides.Default`
  which uses [TailwindCSS](https://tailwindcss.com/) to generate a fairly
  generic looking user interface.

  You can override this by adding your own override modules to the
  `AshAuthentication.Phoenix.Router.sign_in_route/1` macro in your router:

  ```elixir
  sign_in_route overrides: [MyAppWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
  ```

  and defining `lib/my_app_web/auth_overrides.ex` within which you can set any
  overrides.

  The `use` macro defines overridable versions of all callbacks which return
  `nil`, so you only need to define the functions that you care about.

  Each of the override modules specified in the config will be called in the
  order that they're specified, so you can still use the defaults if you just
  override some properties.

  ```elixir
  defmodule MyAppWeb.AuthOverrides do
    use AshAuthentication.Phoenix.Overrides
    alias AshAuthentication.Phoenix.Components

    override Components.Banner do
      set :image_url, "/images/sign_in_logo.png"
    end
  end
  ```
  """

  @doc false
  @spec __using__(any) :: Macro.t()
  defmacro __using__(_env) do
    quote do
      require AshAuthentication.Phoenix.Overrides
      import AshAuthentication.Phoenix.Overrides, only: :macros
      Module.register_attribute(__MODULE__, :override, accumulate: true)
      @component nil
      @before_compile AshAuthentication.Phoenix.Overrides
    end
  end

  @doc """
  Define overrides for a specific component.
  """
  @spec override(component :: module, do: Macro.t()) :: Macro.t()
  defmacro override(component, do: block) do
    quote do
      @component unquote(component)
      unquote(block)
    end
  end

  @doc """
  Override a setting within a component.
  """
  @spec set(atom, any) :: Macro.t()
  defmacro set(selector, value) do
    quote do
      @override {@component, unquote(selector), unquote(value)}
    end
  end

  @doc false
  @spec __before_compile__(any) :: Macro.t()
  defmacro __before_compile__(env) do
    overrides =
      env.module
      |> Module.get_attribute(:override, [])
      |> Map.new(fn {component, selector, value} -> {{component, selector}, value} end)
      |> Macro.escape()

    quote do
      def overrides do
        unquote(overrides)
      end
    end
  end
end
