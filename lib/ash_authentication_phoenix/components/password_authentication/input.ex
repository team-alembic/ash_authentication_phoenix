defmodule AshAuthentication.Phoenix.Components.PasswordAuthentication.Input do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    field_class: "CSS class for `div` elements surrounding the fields.",
    label_class: "CSS class for `label` elements.",
    input_class: "CSS class for text/password `input` elements.",
    input_class_with_error:
      "CSS class for text/password `input` elements when there is a validation error.",
    submit_class: "CSS class for the form submit `input` element.",
    error_ul: "CSS class for the `ul` element on error lists.",
    error_li: "CSS class for the `li` elements on error lists."

  @moduledoc """
  Function components for dealing with form input during password authentication.

  ## Component heirarchy

  These function components are consumed by
  `AshAuthentication.Phoenix.Components.PasswordAuthentication.SignInForm` and
  `AshAuthentication.Phoenix.Components.PasswordAuthentication.RegisterForm`.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use Phoenix.Component
  alias AshAuthentication.PasswordAuthentication.Info
  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}
  import Phoenix.HTML.Form

  @doc """
  Generate a form field for the configured identity field.

  ## Props

    * `socket` - Phoenix LiveView socket.
      This is needed to be able to retrieve the correct CSS configuration.
      Required.
    * `config` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.
      Required.
    * `form` - An `AshPhoenix.Form`.
      Required.
    * `input_type` - Either `:text` or `:email`.
      If not set it will try and guess based on the name of the identity field.
  """
  @spec identity_field(%{
          required(:socket) => Socket.t(),
          required(:config) => AshAuthentication.resource_config(),
          required(:form) => AshPhoenix.Form.t(),
          optional(:input_type) => :text | :email
        }) :: Rendered.t() | no_return
  def identity_field(assigns) do
    identity_field = Info.identity_field!(assigns.config.resource)

    assigns =
      assigns
      |> assign(:identity_field, identity_field)
      |> assign_new(:input_type, fn ->
        identity_field
        |> to_string()
        |> String.starts_with?("email")
        |> then(fn
          true -> :email
          _ -> :text
        end)
      end)
      |> assign_new(:input_class, fn ->
        if has_error?(assigns.form, identity_field) do
          override_for(assigns.socket, :input_class_with_error)
        else
          override_for(assigns.socket, :input_class)
        end
      end)

    ~H"""
    <div class={override_for(@socket, :field_class)}>
      <%= label(@form, @identity_field, class: override_for(@socket, :label_class)) %>
      <%= text_input(@form, @identity_field, type: to_string(@input_type), class: @input_class) %>
      <.error socket={@socket} form={@form} field={@identity_field} />
    </div>
    """
  end

  @doc """
  Generate a form field for the configured password entry field.

  ## Props

    * `socket` - Phoenix LiveView socket.
      This is needed to be able to retrieve the correct CSS configuration.
      Required.
    * `config` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.
      Required.
    * `form` - An `AshPhoenix.Form`.
      Required.
  """
  @spec password_field(%{
          required(:socket) => Socket.t(),
          required(:config) => AshAuthentication.resource_config(),
          required(:form) => AshPhoenix.Form.t()
        }) :: Rendered.t() | no_return
  def password_field(assigns) do
    password_field = Info.password_field!(assigns.config.resource)

    assigns =
      assigns
      |> assign(:password_field, password_field)
      |> assign_new(:input_class, fn ->
        if has_error?(assigns.form, password_field) do
          override_for(assigns.socket, :input_class_with_error)
        else
          override_for(assigns.socket, :input_class)
        end
      end)

    ~H"""
    <div class={override_for(@socket, :field_class)}>
      <%= label(@form, @password_field, class: override_for(@socket, :label_class)) %>
      <%= password_input(@form, @password_field,
        class: @input_class,
        value: input_value(@form, @password_field)
      ) %>
      <.error socket={@socket} form={@form} field={@password_field} />
    </div>
    """
  end

  @doc """
  Generate a form field for the configured password confirmation entry field.

  ## Props

    * `socket` - Phoenix LiveView socket.
      This is needed to be able to retrieve the correct CSS configuration.
      Required.
    * `config` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.
      Required.
    * `form` - An `AshPhoenix.Form`.
      Required.
  """
  @spec password_confirmation_field(%{
          required(:socket) => Socket.t(),
          required(:config) => AshAuthentication.resource_config(),
          required(:form) => AshPhoenix.Form.t()
        }) :: Rendered.t() | no_return
  def password_confirmation_field(assigns) do
    password_confirmation_field = Info.password_confirmation_field!(assigns.config.resource)

    assigns =
      assigns
      |> assign(:password_confirmation_field, password_confirmation_field)
      |> assign_new(:input_class, fn ->
        if has_error?(assigns.form, password_confirmation_field) do
          override_for(assigns.socket, :input_class_with_error)
        else
          override_for(assigns.socket, :input_class)
        end
      end)

    ~H"""
    <div class={override_for(@socket, :field_class)}>
      <%= label(@form, @password_confirmation_field, class: override_for(@socket, :label_class)) %>
      <%= password_input(@form, @password_confirmation_field,
        class: @input_class,
        value: input_value(@form, @password_confirmation_field)
      ) %>
      <.error socket={@socket} form={@form} field={@password_confirmation_field} />
    </div>
    """
  end

  @doc """
  Generate an form submit button.

  ## Props

    * `socket` - Phoenix LiveView socket.
      This is needed to be able to retrieve the correct CSS configuration.
      Required.
    * `config` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.
      Required.
    * `form` - An `AshPhoenix.Form`.
      Required.
    * `action` - Either `:sign_in` or `:register`.
      Required.
    * `label` - The text to show in the submit label.
      Generated from the configured action name (via
      `Phoenix.HTML.Form.humanize/1`) if not supplied.
  """
  @spec submit(%{
          required(:socket) => Socket.t(),
          required(:config) => AshAuthentication.resource_config(),
          required(:form) => AshPhoenix.Form.t(),
          required(:action) => :sign_in | :register,
          optional(:label) => String.t()
        }) :: Rendered.t() | no_return
  def submit(assigns) do
    assigns =
      assigns
      |> assign_new(:label, fn ->
        case assigns.action do
          :sign_in ->
            assigns.config.resource
            |> Info.sign_in_action_name!()

          :register ->
            assigns.config.resource
            |> Info.register_action_name!()
        end
        |> humanize()
      end)

    ~H"""
    <%= submit(@label, class: override_for(@socket, :submit_class)) %>
    """
  end

  @doc """
  Generate a list of errors for a field (if there are any).

  ## Props

    * `socket` - Phoenix LiveView socket.
      This is needed to be able to retrieve the correct CSS configuration.
      Required.
    * `form` - An `AshPhoenix.Form`.
      Required.
    * `field` - The field for which to retrieve the errors.
      Required.
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
      |> assign_new(:errors, fn ->
        assigns.form
        |> Form.errors()
        |> Keyword.get_values(assigns.field)
      end)
      |> assign_new(:field_label, fn -> humanize(assigns.field) end)

    ~H"""
    <%= if Enum.any?(@errors) do %>
      <ul class={override_for(@socket, :error_ul)}>
        <%= for error <- @errors do %>
          <li class={override_for(@socket, :error_li)} phx-feedback-for={input_name(@form, @field)}>
            <%= @field_label %> <%= error %>
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
