defmodule AshAuthentication.Phoenix.Components.WebAuthn.Input do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    identity_input_label: "Label for the identity (email) input field.",
    identity_input_placeholder: "Placeholder for the identity input field.",
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
  alias Phoenix.LiveView.Rendered

  @doc "Renders the identity (email/username) input field."
  @spec identity_field(map) :: Rendered.t()
  def identity_field(assigns) do
    ~H"""
    <div class={override_for(@overrides, :field_class)}>
      <label class={override_for(@overrides, :label_class)}>
        {_gettext(override_for(@overrides, :identity_input_label, "Email"))}
      </label>
      <input
        type="text"
        name={to_string(@identity_field)}
        value={@value}
        placeholder={override_for(@overrides, :identity_input_placeholder, "you@example.com")}
        class={override_for(@overrides, :input_class)}
        phx-change="update-identity"
        autocomplete="username webauthn"
      />
    </div>
    """
  end

  @doc "Renders the register button."
  @spec register_button(map) :: Rendered.t()
  def register_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="register"
      disabled={@disabled}
      class={override_for(@overrides, :submit_class)}
    >
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
    <button
      type="button"
      phx-click="authenticate"
      disabled={@disabled}
      class={override_for(@overrides, :submit_class)}
    >
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
