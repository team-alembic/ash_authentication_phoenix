defmodule AshAuthentication.Phoenix.Components.PasswordAuthentication.ResetForm do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the `h2` element.",
    form_class: "CSS class for the `form` element.",
    slot_class: "CSS class for the `div` surrounding the slot.",
    reset_flash_text:
      "Text for the flash message when a request is received.  Set to `nil` to disable.",
    disable_button_text: "Text for the submit button when the request is happening."

  @moduledoc """
  Generates a default password reset form.

  ## Component hierarchy

  This is a child of `AshAuthentication.Phoenix.Components.PasswordAuthentication`.

  Children:

    * `AshAuthentication.Phoenix.Components.PasswordAuthentication.Input.identity_field/1`
    * `AshAuthentication.Phoenix.Components.PasswordAuthentication.Input.submit/1`

  ## Props

    * `config` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.
      Required.
    * `label` - The text to show in the submit label.
      Generated from the configured action name (via
      `Phoenix.HTML.Form.humanize/1`) if not supplied.
      Set to `false` to disable.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use Phoenix.LiveComponent

  alias AshAuthentication.{
    PasswordAuthentication,
    PasswordReset,
    Phoenix.Components.PasswordAuthentication.Input
  }

  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}
  import Phoenix.HTML.Form

  @doc false
  @impl true
  @spec update(Socket.assigns(), Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    config = assigns.config
    form = blank_form(config)

    socket =
      socket
      |> assign(assigns)
      |> assign(form: form)
      |> assign_new(:label, fn ->
        humanize(PasswordReset.Info.request_password_reset_action_name!(config.resource))
      end)
      |> assign_new(:inner_block, fn -> nil end)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@socket, :root_class)}>
      <%= if @label do %>
        <h2 class={override_for(@socket, :label_class)}>
          <%= @label %>
        </h2>
      <% end %>

      <.form
        :let={form}
        for={@form}
        phx-submit="submit"
        phx-change="change"
        phx-target={@myself}
        class={override_for(@socket, :form_class)}
      >
        <%= hidden_input(form, :action, value: "request_password_reset") %>

        <Input.identity_field socket={@socket} config={@config} form={form} />

        <%= if @inner_block do %>
          <div class={override_for(@socket, :slot_class)}>
            <%= render_slot(@inner_block) %>
          </div>
        <% end %>

        <Input.submit
          socket={@socket}
          config={@config}
          form={form}
          action={:request_reset}
          disable_text={override_for(@socket, :disable_button_text)}
        />
      </.form>
    </div>
    """
  end

  @doc false
  @impl true
  @spec handle_event(String.t(), %{required(String.t()) => String.t()}, Socket.t()) ::
          {:noreply, Socket.t()}

  def handle_event("change", params, socket) do
    config = socket.assigns.config
    params = Map.get(params, to_string(config.subject_name))

    form =
      socket.assigns.form
      |> Form.validate(params, errors: false)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", params, socket) do
    config = socket.assigns.config
    params = Map.get(params, to_string(config.subject_name))

    socket.assigns.form
    |> Form.validate(params)
    |> Form.submit()

    flash = override_for(socket, :reset_flash_text)

    socket =
      socket
      |> assign(:form, blank_form(config))

    socket =
      if flash do
        socket
        |> put_flash(:info, flash)
      else
        socket
      end

    {:noreply, socket}
  end

  defp blank_form(config) do
    action = PasswordReset.Info.request_password_reset_action_name!(config.resource)

    config.resource
    |> Form.for_action(action,
      api: config.api,
      as: to_string(config.subject_name),
      id: "#{PasswordAuthentication.provides()}_#{config.subject_name}_#{action}"
    )
  end
end
