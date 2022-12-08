defmodule AshAuthentication.Phoenix.Components.Password.ResetForm do
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

  This is a child of `AshAuthentication.Phoenix.Components.Password`.

  Children:

    * `AshAuthentication.Phoenix.Components.Password.Input.identity_field/1`
    * `AshAuthentication.Phoenix.Components.Password.Input.submit/1`

  ## Props

    * `strategy` - The configuration map as per
      `AshAuthentication.Info.strategy/2`. Required.
    * `label` - The text to show in the submit label.  Generated from the
      configured action name (via `Phoenix.HTML.Form.humanize/1`) if not
      supplied.  Set to `false` to disable.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use Phoenix.LiveComponent

  alias AshAuthentication.{Info, Phoenix.Components.Password.Input}

  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}
  import AshAuthentication.Phoenix.Components.Helpers
  import Slug

  @doc false
  @impl true
  @spec update(Socket.assigns(), Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    strategy = assigns.strategy
    form = blank_form(strategy)

    socket =
      socket
      |> assign(assigns)
      |> assign(form: form, subject_name: Info.authentication_subject_name!(strategy.resource))
      |> assign_new(:label, fn -> strategy.request_password_reset_action_name end)
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
        action={
          route_helpers(@socket).auth_path(
            @socket.endpoint,
            {@subject_name, @strategy.name, :reset_request}
          )
        }
        method="POST"
        class={override_for(@socket, :form_class)}
      >
        <Input.identity_field socket={@socket} strategy={@strategy} form={form} />

        <%= if @inner_block do %>
          <div class={override_for(@socket, :slot_class)}>
            <%= render_slot(@inner_block) %>
          </div>
        <% end %>

        <Input.submit
          socket={@socket}
          strategy={@strategy}
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
    params = get_params(params, socket.assigns.strategy)

    form =
      socket.assigns.form
      |> Form.validate(params, errors: false)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", params, socket) do
    strategy = socket.assigns.strategy
    params = get_params(params, strategy)

    socket.assigns.form
    |> Form.validate(params)
    |> Form.submit()

    flash = override_for(socket, :reset_flash_text)

    socket =
      socket
      |> assign(:form, blank_form(strategy))

    socket =
      if flash do
        socket
        |> put_flash(:info, flash)
      else
        socket
      end

    {:noreply, socket}
  end

  defp get_params(params, strategy) do
    param_key =
      strategy.resource
      |> Info.authentication_subject_name!()
      |> to_string()
      |> slugify()

    Map.get(params, param_key, %{})
  end

  defp blank_form(%{resettable: [resettable]} = strategy) do
    api = Info.authentication_api!(strategy.resource)
    subject_name = Info.authentication_subject_name!(strategy.resource)

    strategy.resource
    |> Form.for_action(resettable.request_password_reset_action_name,
      api: api,
      as: subject_name |> to_string(),
      id:
        "#{subject_name}-#{strategy.name}-#{resettable.request_password_reset_action_name}"
        |> slugify(),
      context: %{strategy: strategy}
    )
  end
end
