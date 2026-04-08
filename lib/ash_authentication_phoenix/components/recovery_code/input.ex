defmodule AshAuthentication.Phoenix.Components.RecoveryCode.Input do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    field_class: "CSS class for `div` elements surrounding the fields.",
    label_class: "CSS class for `label` elements.",
    input_class: "CSS class for `input` elements.",
    code_input_label: "Label for recovery code field.",
    code_input_placeholder: "Placeholder for recovery code field.",
    input_class_with_error: "CSS class for `input` elements when there is a validation error.",
    submit_class: "CSS class for the form submit `input` element.",
    error_ul: "CSS class for the `ul` element on error lists.",
    error_li: "CSS class for the `li` elements on error lists.",
    input_debounce: "Number of milliseconds to debounce input by (or `nil` to disable)."

  @moduledoc """
  Function components for recovery code form inputs.

  ## Component hierarchy

  These function components are consumed by
  `AshAuthentication.Phoenix.Components.RecoveryCode.VerifyForm` and
  `AshAuthentication.Phoenix.Components.RecoveryCode.DisplayCodes`.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :component
  alias AshPhoenix.Form
  alias Phoenix.LiveView.Rendered
  import Phoenix.HTML.Form
  import PhoenixHTMLHelpers.Form

  @doc """
  Generate a form field for the recovery code.
  """
  @spec code_field(%{
          required(:form) => Form.t(),
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }) :: Rendered.t() | no_return
  def code_field(assigns) do
    assigns =
      assigns
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:input_class, fn ->
        if has_error?(assigns.form, :code) do
          override_for(assigns.overrides, :input_class_with_error)
        else
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
        autocomplete: "off",
        spellcheck: "false",
        autocapitalize: "characters",
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
  """
  @spec submit(%{
          required(:id) => String.t(),
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
      |> assign_new(:label, fn -> "Verify" end)
      |> assign_new(:disable_text, fn -> nil end)

    ~H"""
    {submit(_gettext(@label),
      class: override_for(@overrides, :submit_class),
      phx_disable_with: _gettext(@disable_text)
    )}
    """
  end

  @doc """
  Generate a list of errors for a field.
  """
  @spec error(%{
          required(:form) => Form.t(),
          required(:field) => atom,
          optional(:overrides) => [module],
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
      |> assign_new(:field_label, fn -> PhoenixHTMLHelpers.Form.humanize(assigns.field) end)

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
