defmodule AshAuthentication.Phoenix.Overrides do
  @moduledoc """
  Behaviour for overriding component styles and attributes in your application.

  The default implementation is `AshAuthentication.Phoenix.Overrides.Default`
  which uses [TailwindCSS](https://tailwindcss.com/) to generate a fairly
  generic looking user interface.

  You can override by setting the following in your `config.exs`:

  ```elixir
  config :my_app, AshAuthentication.Phoenix, overrides: [MyAppWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
  ```

  and defining `lib/my_app_web/auth_styles.ex` within which you can set CSS
  classes for any values you want.

  The `use` macro defines overridable versions of all callbacks which return
  `nil`, so you only need to define the functions that you care about.

  ```elixir
  defmodule MyAppWeb.AuthOverrides do
    use AshAuthentication.Phoenix.Overrides

    override
  end
  ```

  ## Configuration

  """

  @doc """
  Retrieve the override for a specific component and selector.
  """
  @spec override_for(otp_app :: atom, component :: module, selector :: atom) :: any
  def override_for(otp_app, component, selector)
      when is_atom(otp_app) and is_atom(component) and is_atom(selector) do
    otp_app
    |> Application.get_env(AshAuthentication.Phoenix, [])
    |> Keyword.get(:overrides, [__MODULE__.Default])
    |> Enum.find_value(fn module ->
      module.overrides()
      |> Map.get({component, selector})
    end)
  end

  defmacro __using__(_env) do
    quote do
      require AshAuthentication.Phoenix.Overrides
      import AshAuthentication.Phoenix.Overrides, only: :macros
      Module.register_attribute(__MODULE__, :override, accumulate: true)
      @component nil
      @before_compile AshAuthentication.Phoenix.Overrides
    end
  end

  defmacro override(component, do: block) do
    quote do
      @component unquote(component)
      unquote(block)
    end
  end

  defmacro set(selector, value) do
    quote do
      @override {@component, unquote(selector), unquote(value)}
    end
  end

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
