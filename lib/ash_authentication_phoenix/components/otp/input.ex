# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Otp.Input do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    field_class: "CSS class for `div` elements surrounding the fields.",
    label_class: "CSS class for `label` elements.",
    input_class: "CSS class for text/code `input` elements.",
    input_class_with_error:
      "CSS class for text/code `input` elements when there is a validation error.",
    identity_input_label: "Label for the identity field.",
    identity_input_placeholder: "Placeholder for the identity field.",
    code_input_label: "Label for the OTP code field.",
    code_input_placeholder: "Placeholder for the OTP code field.",
    submit_class: "CSS class for the form submit `input` element.",
    request_label:
      "A function that takes the strategy and returns the request submit button text, or a string.",
    verify_label:
      "A function that takes the strategy and returns the verify submit button text, or a string.",
    error_ul: "CSS class for the `ul` element on error lists.",
    error_li: "CSS class for the `li` elements on error lists.",
    input_debounce: "Number of milliseconds to debounce input by (or `nil` to disable)."

  @moduledoc """
  Function components for dealing with form input during OTP authentication.

  ## Component hierarchy

  These function components are consumed by
  `AshAuthentication.Phoenix.Components.Otp.RequestForm` and
  `AshAuthentication.Phoenix.Components.Otp.VerifyForm`.

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

    * `socket` - Phoenix LiveView socket. Required.
    * `strategy` - The configuration map as per
      `AshAuthentication.Info.strategy/2`. Required.
    * `form` - An `AshPhoenix.Form`. Required.
    * `input_type` - Either `:text` or `:email`. If not set, guessed from the
      identity field name.
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
  Generate a form field for the OTP code.

  ## Props

    * `socket` - Phoenix LiveView socket. Required.
    * `strategy` - The configuration map as per
      `AshAuthentication.Info.strategy/2`. Required.
    * `form` - An `AshPhoenix.Form`. Required.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.
  """
  @spec code_field(%{
          required(:socket) => Socket.t(),
          required(:strategy) => Strategy.t(),
          required(:form) => Form.t(),
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }) :: Rendered.t() | no_return
  def code_field(assigns) do
    otp_param_name = assigns.strategy.otp_param_name

    assigns =
      assigns
      |> assign(:otp_param_name, otp_param_name)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:input_class, fn ->
        if has_error?(assigns.form, otp_param_name) do
          override_for(assigns.overrides, :input_class_with_error)
        else
          override_for(assigns.overrides, :input_class)
        end
      end)

    ~H"""
    <div class={override_for(@overrides, :field_class)}>
      {label(@form, @otp_param_name, _gettext(override_for(@overrides, :code_input_label)),
        class: override_for(@overrides, :label_class)
      )}
      {text_input(@form, @otp_param_name,
        type: "text",
        class: @input_class,
        autocomplete: "one-time-code",
        inputmode: "text",
        phx_debounce: override_for(@overrides, :input_debounce),
        autofocus: "true",
        placeholder: override_for(@overrides, :code_input_placeholder)
      )}
      <.error form={@form} field={@otp_param_name} overrides={@overrides} />
    </div>
    """
  end

  @doc """
  Generate a form submit button.

  ## Props

    * `socket` - Phoenix LiveView socket. Required.
    * `strategy` - The configuration map as per
      `AshAuthentication.Info.strategy/2`. Required.
    * `form` - An `AshPhoenix.Form`. Required.
    * `action` - Either `:request` or `:verify`. Required.
    * `label` - Optional override for the submit button label.
    * `disable_text` - Text shown while the request is in flight.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.
  """
  @spec submit(%{
          required(:socket) => Socket.t(),
          required(:strategy) => Strategy.t(),
          required(:form) => Form.t(),
          required(:action) => :request | :verify,
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
      |> assign_new(:disable_text, fn -> nil end)
      |> assign_new(:label, fn ->
        label =
          case assigns.action do
            :request -> override_for(assigns.overrides, :request_label)
            :verify -> override_for(assigns.overrides, :verify_label)
          end || default_label(assigns.action)

        if is_function(label) do
          label.(assigns.strategy)
        else
          label
        end
      end)

    ~H"""
    {submit(_gettext(@label),
      class: override_for(@overrides, :submit_class),
      phx_disable_with: _gettext(@disable_text)
    )}
    """
  end

  defp default_label(:request), do: "Send code"
  defp default_label(:verify), do: "Sign in"

  defp error(assigns) do
    assigns =
      assigns
      |> assign_new(:errors, fn ->
        assigns.form
        |> Form.errors()
        |> Keyword.get_values(assigns.field)
      end)

    ~H"""
    <%= if Enum.any?(@errors) do %>
      <ul class={override_for(@overrides, :error_ul)}>
        <li
          :for={error <- @errors}
          class={override_for(@overrides, :error_li)}
          phx-feedback-for={input_name(@form, @field)}
        >
          {_gettext(error)}
        </li>
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
