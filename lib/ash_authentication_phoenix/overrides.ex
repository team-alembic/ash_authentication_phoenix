defmodule AshAuthentication.Phoenix.Overrides do
  @configurables [
    password_authentication_form_label_css_class: "CSS classes for generated `label` tags",
    password_authentication_form_text_input_css_class:
      "CSS classes for generated `input` tags of type `text`, `email` or `password`",
    password_authentication_form_input_surround_css_class:
      "CSS classes for the div surrounding an `label`/`input` combination.",
    password_authentication_form_h2_css_class: "CSS classes for any form `h2` headers.",
    password_authentication_form_submit_css_class: "CSS classes for any form submit buttons.",
    password_authentication_form_css_class: "CSS classes for any `form` tags.",
    password_authentication_form_error_ul_css_class: "CSS classes for `ul` tags in form errors",
    password_authentication_form_error_li_css_class: "CSS classes for `li` tags in form errors",
    password_authentication_box_css_class:
      "CSS classes for the root `div` element in the `AshAuthentication.Phoenix.Components.PasswordAuthentication` component.",
    password_authentication_box_spacer_css_class:
      "CSS classes for the \"spacer\" in the `AshAuthentication.Phoenix.Components.PasswordAuthentication` component - if enabled.",
    sign_in_box_css_class:
      "CSS classes for the root `div` element in the `AshAuthentication.Phoenix.Components.SignIn` component.",
    sign_in_row_css_class:
      "CSS classes for each row in the `AshAuthentication.Phoenix.Components.SignIn` component.",
    sign_in_live_css_class:
      "CSS classes for the root element of the `AshAuthentication.Phoenix.SignInLive` live view."
  ]

  @moduledoc """
  Behaviour for overriding component styles and attributes in your application.

  The default implementation is `AshAuthentication.Phoenix.Overrides.Default`
  which uses [TailwindCSS](https://tailwindcss.com/) to generate a fairly
  generic looking user interface.

  You can override by setting the following in your `config.exs`:

  ```elixir
  config :my_app, AshAuthentication.Phoenix, override_module: MyAppWeb.AuthOverrides
  ```

  and defining `lib/my_app_web/auth_styles.ex` within which you can set CSS
  classes for any values you want.

  The `use` macro defines overridable versions of all callbacks which return
  `nil`, so you only need to define the functions that you care about.

  ```elixir
  defmodule MyAppWeb.AuthOverrides do
    use AshAuthentication.Phoenix.Overrides

    def password_authentication_form_label_css_class, do: "my-custom-css-class"
  end
  ```

  ## Configuration

  #{Enum.map(@configurables, &"  * `#{elem(&1, 0)}` - #{elem(&1, 1)}\n")}
  """

  alias __MODULE__

  for {name, doc} <- @configurables do
    Module.put_attribute(__MODULE__, :doc, {__ENV__.line, doc})
    @callback unquote({name, [], Elixir}) :: nil | String.t()
  end

  @doc false
  @spec __using__(any) :: Macro.t()
  defmacro __using__(_) do
    quote do
      require Overrides
      @behaviour Overrides

      Overrides.generate_default_implementations()
      Overrides.make_overridable()
    end
  end

  @doc false
  @spec generate_default_implementations :: Macro.t()
  defmacro generate_default_implementations do
    for {name, doc} <- @configurables do
      quote do
        @impl true
        @doc unquote(doc)
        def unquote({name, [], Elixir}), do: nil
      end
    end
  end

  @doc false
  @spec make_overridable :: Macro.t()
  defmacro make_overridable do
    callbacks =
      @configurables
      |> Enum.map(&put_elem(&1, 1, 0))

    quote do
      defoverridable unquote(callbacks)
    end
  end
end
