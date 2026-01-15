# SPDX-FileCopyrightText: 2024 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Totp.Input do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    field_class: "CSS class for `div` elements surrounding the fields.",
    label_class: "CSS class for `label` elements.",
    input_class: "CSS class for `input` elements.",
    identity_input_label: "Label for identity field.",
    identity_input_placeholder: "Placeholder for identity field.",
    code_input_label: "Label for TOTP code field.",
    code_input_placeholder: "Placeholder for TOTP code field.",
    input_class_with_error: "CSS class for `input` elements when there is a validation error.",
    submit_class: "CSS class for the form submit `input` element.",
    error_ul: "CSS class for the `ul` element on error lists.",
    error_li: "CSS class for the `li` elements on error lists.",
    input_debounce: "Number of milliseconds to debounce input by (or `nil` to disable).",
    valid_code_class: "CSS class applied to code field when validation passes.",
    invalid_code_class: "CSS class applied to code field when validation fails."

  @moduledoc """
  Function components for dealing with form input during TOTP authentication.

  ## Component hierarchy

  These function components are consumed by
  `AshAuthentication.Phoenix.Components.Totp.SignInForm` and
  `AshAuthentication.Phoenix.Components.Totp.SetupForm`.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :component
  alias AshAuthentication.Strategy
  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}
  import Phoenix.HTML.Form
  import PhoenixHTMLHelpers.Form

  @doc """
  Generate a form field for the configured identity field.

  ## Props

    * `socket` - Phoenix LiveView socket.
      This is needed to be able to retrieve the correct CSS configuration.
      Required.
    * `strategy` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.
      Required.
    * `form` - An `AshPhoenix.Form`.
      Required.
    * `input_type` - Either `:text` or `:email`.
      If not set it will try and guess based on the name of the identity field.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.
  """
  @spec identity_field(%{
          required(:socket) => Socket.t(),
          required(:strategy) => Strategy.t(),
          required(:form) => Form.t(),
          optional(:input_type) => :text | :email,
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }) :: Rendered.t() | no_return
  def identity_field(assigns) do
    identity_field = assigns.strategy.identity_field

    assigns =
      assigns
      |> assign(:identity_field, identity_field)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:input_type, fn ->
        identity_field
        |> to_string()
        |> String.contains?("email")
        |> then(fn
          true -> :email
          _ -> :text
        end)
      end)
      |> assign_new(:input_class, fn ->
        if has_error?(assigns.form, identity_field) do
          override_for(assigns.overrides, :input_class_with_error)
        else
          override_for(assigns.overrides, :input_class)
        end
      end)

    ~H"""
    <div class={override_for(@overrides, :field_class)}>
      {label(@form, @identity_field, _gettext(override_for(@overrides, :identity_input_label)),
        class: override_for(@overrides, :label_class)
      )}
      {text_input(@form, @identity_field,
        type: to_string(@input_type),
        class: @input_class,
        phx_debounce: override_for(@overrides, :input_debounce),
        autofocus: "true",
        placeholder: override_for(@overrides, :identity_input_placeholder)
      )}
      <.error form={@form} field={@identity_field} overrides={@overrides} />
    </div>
    """
  end

  @doc """
  Generate a form field for the TOTP code.

  ## Props

    * `socket` - Phoenix LiveView socket. Required.
    * `strategy` - The strategy configuration. Required.
    * `form` - An `AshPhoenix.Form`. Required.
    * `code_valid` - Boolean indicating if the code is currently valid (for setup forms).
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.
  """
  @spec code_field(%{
          required(:socket) => Socket.t(),
          required(:strategy) => Strategy.t(),
          required(:form) => Form.t(),
          optional(:code_valid) => boolean | nil,
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }) :: Rendered.t() | no_return
  def code_field(assigns) do
    assigns =
      assigns
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:code_valid, fn -> nil end)
      |> assign_new(:input_class, fn ->
        cond do
          has_error?(assigns.form, :code) ->
            override_for(assigns.overrides, :input_class_with_error)

          assigns[:code_valid] == true ->
            override_for(assigns.overrides, :valid_code_class) ||
              override_for(assigns.overrides, :input_class)

          assigns[:code_valid] == false ->
            override_for(assigns.overrides, :invalid_code_class) ||
              override_for(assigns.overrides, :input_class_with_error)

          true ->
            override_for(assigns.overrides, :input_class)
        end
      end)

    ~H"""
    <div class={override_for(@overrides, :field_class)}>
      {label(@form, :code, _gettext(override_for(@overrides, :code_input_label)),
        class: override_for(@overrides, :label_class)
      )}
      {text_input(@form, :code,
        type: "text",
        inputmode: "numeric",
        pattern: "[0-9]{6}",
        maxlength: "6",
        autocomplete: "one-time-code",
        class: @input_class,
        phx_debounce: override_for(@overrides, :input_debounce),
        placeholder: override_for(@overrides, :code_input_placeholder)
      )}
      <.error form={@form} field={:code} overrides={@overrides} />
    </div>
    """
  end

  @doc """
  Generate a form submit button.

  ## Props

    * `socket` - Phoenix LiveView socket. Required.
    * `strategy` - The strategy configuration. Required.
    * `form` - An `AshPhoenix.Form`. Required.
    * `action` - Either `:sign_in`, `:setup`, or `:confirm_setup`. Required.
    * `label` - The text to show in the submit label.
    * `disable_text` - Text to show when the button is disabled.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.
  """
  @spec submit(%{
          required(:socket) => Socket.t(),
          required(:strategy) => Strategy.t(),
          required(:form) => Form.t(),
          required(:action) => :sign_in | :setup | :confirm_setup,
          optional(:label) => String.t(),
          optional(:disable_text) => String.t(),
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }) :: Rendered.t() | no_return
  def submit(assigns) do
    assigns =
      assigns
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:label, fn ->
        case assigns.action do
          :sign_in -> "Sign in"
          :setup -> "Set up"
          :confirm_setup -> "Confirm"
          other -> humanize(other)
        end
      end)
      |> assign_new(:disable_text, fn -> nil end)

    ~H"""
    {submit(_gettext(@label),
      class: override_for(@overrides, :submit_class),
      phx_disable_with: _gettext(@disable_text)
    )}
    """
  end

  @doc """
  Generate a list of errors for a field (if there are any).

  ## Props

    * `socket` - Phoenix LiveView socket. Required.
    * `form` - An `AshPhoenix.Form`. Required.
    * `field` - The field for which to retrieve the errors. Required.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.
  """
  @spec error(%{
          required(:socket) => Socket.t(),
          required(:form) => Form.t(),
          required(:field) => atom,
          optional(:field_label) => String.Chars.t(),
          optional(:errors) => [{atom, String.t()}],
          optional(:gettext_fn) => {module, atom}
        }) :: Rendered.t() | no_return
  def error(assigns) do
    assigns =
      assigns
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:errors, fn ->
        assigns.form
        |> Form.errors()
        |> Keyword.get_values(assigns.field)
      end)
      |> assign_new(:field_label, fn -> humanize(assigns.field) end)

    ~H"""
    <%= if Enum.any?(@errors) do %>
      <ul class={override_for(@overrides, :error_ul)}>
        <%= for error <- @errors do %>
          <li class={override_for(@overrides, :error_li)} phx-feedback-for={input_name(@form, @field)}>
            {_gettext(error)}
          </li>
        <% end %>
      </ul>
    <% end %>
    """
  end

  defp has_error?(form, field) do
    form
    |> Form.errors()
    |> Keyword.has_key?(field)
  end
end
