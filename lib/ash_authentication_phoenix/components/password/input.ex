defmodule AshAuthentication.Phoenix.Components.Password.Input do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    field_class: "CSS class for `div` elements surrounding the fields.",
    label_class: "CSS class for `label` elements.",
    input_class: "CSS class for text/password `input` elements.",
    input_class_with_error:
      "CSS class for text/password `input` elements when there is a validation error.",
    submit_class: "CSS class for the form submit `input` element.",
    error_ul: "CSS class for the `ul` element on error lists.",
    error_li: "CSS class for the `li` elements on error lists.",
    input_debounce: "Number of milliseconds to debounce input by (or `nil` to disable)."

  @moduledoc """
  Function components for dealing with form input during password
  authentication.

  ## Component hierarchy

  These function components are consumed by
  `AshAuthentication.Phoenix.Components.Password.SignInForm`,
  `AshAuthentication.Phoenix.Components.Password.RegisterForm` and
  `AshAuthentication.Phoenix.Components.ResetForm`.

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
  """
  @spec identity_field(%{
          required(:socket) => Socket.t(),
          required(:strategy) => Strategy.t(),
          required(:form) => Form.t(),
          optional(:input_type) => :text | :email,
          optional(:overrides) => [module]
        }) :: Rendered.t() | no_return
  def identity_field(assigns) do
    identity_field = assigns.strategy.identity_field

    assigns =
      assigns
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)

    assigns =
      assigns
      |> assign(:identity_field, identity_field)
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
      <%= label(@form, @identity_field, class: override_for(@overrides, :label_class)) %>
      <%= text_input(@form, @identity_field,
        type: to_string(@input_type),
        class: @input_class,
        phx_debounce: override_for(@overrides, :input_debounce),
        autofocus: "true"
      ) %>
      <.error form={@form} field={@identity_field} overrides={@overrides} />
    </div>
    """
  end

  @doc """
  Generate a form field for the configured password entry field.

  ## Props

    * `socket` - Phoenix LiveView socket.  This is needed to be able to retrieve
      the correct CSS configuration.  Required.
    * `strategy` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.  Required.
    * `form` - An `AshPhoenix.Form`.  Required.
    * `overrides` - A list of override modules.
  """
  @spec password_field(%{
          required(:socket) => Socket.t(),
          required(:strategy) => Strategy.t(),
          required(:form) => Form.t(),
          optional(:overrides) => [module]
        }) :: Rendered.t() | no_return
  def password_field(assigns) do
    password_field = assigns.strategy.password_field

    assigns =
      assigns
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)

    assigns =
      assigns
      |> assign(:password_field, password_field)
      |> assign_new(:input_class, fn ->
        if has_error?(assigns.form, password_field) do
          override_for(assigns.overrides, :input_class_with_error)
        else
          override_for(assigns.overrides, :input_class)
        end
      end)

    ~H"""
    <div class={override_for(@overrides, :field_class)}>
      <%= label(@form, @password_field, class: override_for(@overrides, :label_class)) %>
      <%= password_input(@form, @password_field,
        class: @input_class,
        value: input_value(@form, @password_field),
        phx_debounce: override_for(@overrides, :input_debounce)
      ) %>
      <.error form={@form} field={@password_field} overrides={@overrides} />
    </div>
    """
  end

  @doc """
  Generate a form field for the configured password confirmation entry field.

  ## Props

    * `socket` - Phoenix LiveView socket.  This is needed to be able to retrieve
      the correct CSS configuration.  Required.
    * `strategy` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.  Required.
    * `form` - An `AshPhoenix.Form`.  Required.
    * `overrides` - A list of override modules.
  """
  @spec password_confirmation_field(%{
          required(:socket) => Socket.t(),
          required(:strategy) => Strategy.t(),
          required(:form) => Form.t(),
          optional(:overrides) => [module]
        }) :: Rendered.t() | no_return
  def password_confirmation_field(assigns) do
    password_confirmation_field = assigns.strategy.password_confirmation_field

    assigns =
      assigns
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)

    assigns =
      assigns
      |> assign(:password_confirmation_field, password_confirmation_field)
      |> assign_new(:input_class, fn ->
        if has_error?(assigns.form, password_confirmation_field) do
          override_for(assigns.overrides, :input_class_with_error)
        else
          override_for(assigns.overrides, :input_class)
        end
      end)

    ~H"""
    <div class={override_for(@overrides, :field_class)}>
      <%= label(@form, @password_confirmation_field, class: override_for(@overrides, :label_class)) %>
      <%= password_input(@form, @password_confirmation_field,
        class: @input_class,
        value: input_value(@form, @password_confirmation_field),
        phx_debounce: override_for(@overrides, :input_debounce)
      ) %>
      <.error form={@form} field={@password_confirmation_field} overrides={@overrides} />
    </div>
    """
  end

  @doc """
  Generate an form submit button.

  ## Props

    * `socket` - Phoenix LiveView socket.  This is needed to be able to retrieve
      the correct CSS configuration.  Required.
    * `strategy` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.  Required.
    * `form` - An `AshPhoenix.Form`.  Required.
    * `action` - Either `:sign_in` or `:register`.  Required.
    * `label` - The text to show in the submit label.  Generated from the
      configured action name (via `Phoenix.Naming.humanize/1`) if not supplied.
    * `overrides` - A list of override modules.
  """
  @spec submit(%{
          required(:socket) => Socket.t(),
          required(:strategy) => Strategy.t(),
          required(:form) => Form.t(),
          required(:action) => :sign_in | :register,
          optional(:label) => String.t(),
          optional(:overrides) => [module]
        }) :: Rendered.t() | no_return
  def submit(assigns) do
    assigns =
      assigns
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:label, fn ->
        case assigns.action do
          :request_reset ->
            assigns.strategy.resettable
            |> Kernel.||(%{})
            |> Map.get(:request_password_reset_action_name, :reset_request)
            |> to_string()
            |> String.trim_trailing("_with_password")

          :sign_in ->
            assigns.strategy.sign_in_action_name
            |> to_string()
            |> String.trim_trailing("_with_password")

          :register ->
            assigns.strategy.register_action_name
            |> to_string()
            |> String.trim_trailing("_with_password")

          other ->
            other
        end
        |> humanize()
      end)
      |> assign_new(:disable_text, fn -> nil end)

    ~H"""
    <%= submit(@label,
      class: override_for(@overrides, :submit_class),
      phx_disable_with: @disable_text
    ) %>
    """
  end

  @doc """
  Generate a list of errors for a field (if there are any).

  ## Props

    * `socket` - Phoenix LiveView socket.  This is needed to be able to retrieve
      the correct CSS configuration.  Required.
    * `form` - An `AshPhoenix.Form`.  Required.
    * `field` - The field for which to retrieve the errors.  Required.
    * `overrides` - A list of override modules.
  """
  @spec error(%{
          required(:socket) => Socket.t(),
          required(:form) => Form.t(),
          required(:field) => atom,
          optional(:field_label) => String.Chars.t(),
          optional(:errors) => [{atom, String.t()}]
        }) :: Rendered.t() | no_return
  def error(assigns) do
    assigns =
      assigns
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
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
            <%= error %>
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
