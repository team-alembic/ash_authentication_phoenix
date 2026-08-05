# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.WebAuthn.Input do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    identity_input_label:
      "Label for the identity input. Defaults to the humanized field name (e.g. `:email` → \"Email\").",
    identity_input_placeholder: "Placeholder for the identity input field.",
    key_name_label: "Label for the optional passkey name field.",
    key_name_placeholder: "Placeholder for the passkey name field.",
    display_name_label: "Label for the display name field (passkey-first mode).",
    display_name_placeholder: "Placeholder for the display name field.",
    field_class: "CSS class for the field wrapper `div`.",
    label_class: "CSS class for `label` elements.",
    input_class: "CSS class for `input` elements.",
    submit_class: "CSS class for the submit `button` element.",
    error_ul: "CSS class for the error list `ul` element.",
    error_li: "CSS class for the error list `li` elements.",
    input_class_with_error: "CSS class for `input` elements when there is an error.",
    register_button_text: "Text for the register button.",
    register_button_icon:
      "SVG icon for the register button (or nil to hide). Must be trusted static SVG — rendered with Phoenix.HTML.raw().",
    sign_in_button_text: "Text for the sign in button.",
    sign_in_button_icon:
      "SVG icon for the sign in button (or nil to hide). Must be trusted static SVG — rendered with Phoenix.HTML.raw().",
    disable_button_text: "Text shown on the button while submitting."

  @moduledoc """
  Function components for WebAuthn form inputs.

  These are used by the registration and authentication form components
  to render individual form fields.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :component
  alias AshPhoenix.Form
  alias Phoenix.LiveView.Rendered
  import Phoenix.HTML.Form, only: [input_value: 2]

  @doc """
  Renders the identity (email/username) input field.

  When a `form` prop (an `AshPhoenix.Form`) is given, the input is bound to
  the form's identity field and validation errors for it are rendered below
  the input. Otherwise a bare input named after the identity field is
  rendered (with an optional `value` prop).
  """
  @spec identity_field(map) :: Rendered.t()
  def identity_field(assigns) do
    assigns =
      assigns
      |> assign_new(:form, fn -> nil end)
      |> assign_new(:value, fn ->
        if assigns[:form], do: input_value(assigns.form, assigns.identity_field), else: ""
      end)

    assigns =
      assigns
      |> assign(:input_id, assigns[:id] || Phoenix.Naming.humanize(assigns.identity_field))
      |> assign(:input_name, input_name_for(assigns.form, assigns.identity_field))
      |> assign(:errors, field_errors(assigns.form, assigns.identity_field))

    assigns =
      assign(assigns, :input_class, input_class_for(assigns.overrides, assigns.errors))

    ~H"""
    <div class={override_for(@overrides, :field_class)}>
      <label for={@input_id} class={override_for(@overrides, :label_class)}>
        {override_for(@overrides, :identity_input_label) ||
          Phoenix.Naming.humanize(@identity_field)}
      </label>
      <input
        type="text"
        id={@input_id}
        name={@input_name}
        value={@value}
        placeholder={override_for(@overrides, :identity_input_placeholder)}
        class={@input_class}
        autocomplete="username webauthn"
        phx-debounce="300"
      />
      <%= if Enum.any?(@errors) do %>
        <ul class={override_for(@overrides, :error_ul)}>
          <li :for={error <- @errors} class={override_for(@overrides, :error_li)}>
            {_gettext(error)}
          </li>
        </ul>
      <% end %>
    </div>
    """
  end

  defp input_name_for(nil, field), do: to_string(field)
  defp input_name_for(form, field), do: Phoenix.HTML.Form.input_name(form, field)

  defp field_errors(nil, _field), do: []

  defp field_errors(form, field) do
    form
    |> Form.errors()
    |> Keyword.get_values(field)
  end

  defp input_class_for(overrides, []), do: override_for(overrides, :input_class)

  defp input_class_for(overrides, _errors) do
    override_for(overrides, :input_class_with_error) || override_for(overrides, :input_class)
  end

  @doc "Renders the optional passkey name input."
  @spec key_name_field(map) :: Rendered.t()
  def key_name_field(assigns) do
    assigns = assign(assigns, :input_id, assigns[:id] || "key_name")

    ~H"""
    <div class={override_for(@overrides, :field_class)}>
      <label for={@input_id} class={override_for(@overrides, :label_class)}>
        {_gettext(override_for(@overrides, :key_name_label, "Passkey name"))}
      </label>
      <input
        type="text"
        id={@input_id}
        name="key_name"
        value={@value}
        placeholder={override_for(@overrides, :key_name_placeholder, "My passkey")}
        class={override_for(@overrides, :input_class)}
        autocomplete="off"
        phx-debounce="300"
      />
    </div>
    """
  end

  @doc """
  Renders the display name input (passkey-first mode).

  With no identity field on the registration form, this value is the only
  way to label the account inside the passkey — it becomes the
  `user.displayName` shown in the OS passkey picker. Distinct from the
  passkey name (`key_name_field/1`), which names the credential/device
  server-side.
  """
  @spec display_name_field(map) :: Rendered.t()
  def display_name_field(assigns) do
    assigns = assign(assigns, :input_id, assigns[:id] || "display_name")

    ~H"""
    <div class={override_for(@overrides, :field_class)}>
      <label for={@input_id} class={override_for(@overrides, :label_class)}>
        {_gettext(override_for(@overrides, :display_name_label, "Your name"))}
      </label>
      <input
        type="text"
        id={@input_id}
        name="display_name"
        value={@value}
        placeholder={override_for(@overrides, :display_name_placeholder, "Jane Doe")}
        class={override_for(@overrides, :input_class)}
        autocomplete="name"
        phx-debounce="300"
      />
    </div>
    """
  end

  @doc "Renders the register button."
  @spec register_button(map) :: Rendered.t()
  def register_button(assigns) do
    ~H"""
    <button type="submit" disabled={@disabled} class={override_for(@overrides, :submit_class)}>
      <%= if icon = override_for(@overrides, :register_button_icon) do %>
        {Phoenix.HTML.raw(icon)}
      <% end %>
      {_gettext(override_for(@overrides, :register_button_text, "Register with Passkey"))}
    </button>
    """
  end

  @doc "Renders the sign-in button."
  @spec sign_in_button(map) :: Rendered.t()
  def sign_in_button(assigns) do
    ~H"""
    <button type="submit" disabled={@disabled} class={override_for(@overrides, :submit_class)}>
      <%= if icon = override_for(@overrides, :sign_in_button_icon) do %>
        {Phoenix.HTML.raw(icon)}
      <% end %>
      {_gettext(override_for(@overrides, :sign_in_button_text, "Sign in with Passkey"))}
    </button>
    """
  end

  @doc "Renders an error message."
  @spec error(map) :: Rendered.t()
  def error(assigns) do
    ~H"""
    <%= if @message do %>
      <ul class={override_for(@overrides, :error_ul)}>
        <li class={override_for(@overrides, :error_li)}>{_gettext(@message)}</li>
      </ul>
    <% end %>
    """
  end

  @key_icon """
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5 mr-2">
    <path fill-rule="evenodd" d="M15.75 1.5a6.75 6.75 0 00-6.651 7.906c.067.39-.032.717-.221.906l-6.5 6.499a3 3 0 00-.878 2.121v2.818c0 .414.336.75.75.75H6a.75.75 0 00.75-.75v-1.5h1.5A.75.75 0 009 19.5V18h1.5a.75.75 0 00.53-.22l2.658-2.658c.19-.189.517-.288.906-.22A6.75 6.75 0 1015.75 1.5zm0 3a.75.75 0 000 1.5A2.25 2.25 0 0118 8.25a.75.75 0 001.5 0 3.75 3.75 0 00-3.75-3.75z" clip-rule="evenodd" />
  </svg>
  """

  @doc false
  def default_key_icon, do: @key_icon
end
