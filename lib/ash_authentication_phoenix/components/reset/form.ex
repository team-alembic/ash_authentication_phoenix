defmodule AshAuthentication.Phoenix.Components.Reset.Form do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the `h2` element.",
    form_class: "CSS class for the `form` element.",
    spacer_class: "CSS classes for space between the password input and submit elements.",
    disable_button_text: "Text for the submit button when the request is happening."

  @moduledoc """
  Generates a default password reset form.

  ## Component hierarchy

  This is a child of `AshAuthentication.Phoenix.Components.Reset`.

  Children:

    * `AshAuthentication.Phoenix.Components.Password.Input.identity_field/1`
    * `AshAuthentication.Phoenix.Components.Password.Input.password_field/1`
    * `AshAuthentication.Phoenix.Components.Password.Input.submit/1`
    * `AshAuthentication.Phoenix.Components.Password.Input.error/1`

  ## Props

    * `token` - The reset token.
    * `socket` - Phoenix LiveView socket.  This is needed to be able to retrieve
      the correct CSS configuration. Required.
    * `strategy` - The configuration map as per
      `AshAuthentication.Info.strategy/2`. Required.
    * `label` - The text to show in the submit label. Generated from the
      configured action name (via `Phoenix.HTML.Form.humanize/1`) if not
      supplied. Set to `false` to disable.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use Phoenix.LiveComponent
  alias AshAuthentication.{Info, Phoenix.Components.Password.Input, Strategy}
  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}
  import AshAuthentication.Phoenix.Components.Helpers, only: [route_helpers: 1]
  import Phoenix.HTML.Form
  import Slug

  @type props :: %{
          required(:socket) => Socket.t(),
          required(:strategy) => AshAuthentication.Strategy.t(),
          required(:token) => String.t(),
          optional(:label) => String.t() | false,
          optional(:overrices) => [module]
        }

  @doc false
  @impl true
  @spec update(props, Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    strategy = assigns.strategy
    api = Info.authentication_api!(strategy.resource)
    subject_name = Info.authentication_subject_name!(strategy.resource)

    [resettable] = strategy.resettable

    form =
      strategy.resource
      |> Form.for_action(resettable.password_reset_action_name,
        api: api,
        as: subject_name |> to_string(),
        id:
          "#{subject_name}-#{Strategy.name(strategy)}-#{resettable.password_reset_action_name}"
          |> slugify(),
        context: %{strategy: strategy, private: %{ash_authentication?: true}}
      )

    socket =
      socket
      |> assign(assigns)
      |> assign(
        form: form,
        trigger_action: false,
        subject_name: subject_name,
        resettable: resettable
      )
      |> assign_new(:label, fn -> humanize(resettable.password_reset_action_name) end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= if @label do %>
        <h2 class={override_for(@overrides, :label_class)}><%= @label %></h2>
      <% end %>

      <.form
        :let={form}
        for={@form}
        phx-change="change"
        phx-submit="submit"
        phx-trigger-action={@trigger_action}
        phx-target={@myself}
        action={
          route_helpers(@socket).auth_path(
            @socket.endpoint,
            {@subject_name, Strategy.name(@strategy), :reset}
          )
        }
        method="POST"
        class={override_for(@overrides, :form_class)}
      >
        <%= hidden_input(form, :reset_token, value: @token) %>
        <Input.error socket={@socket} field={:reset_token} form={@form} overrides={@overrides} />

        <Input.password_field
          socket={@socket}
          strategy={@strategy}
          form={form}
          overrides={@overrides}
        />

        <%= if @strategy.confirmation_required? do %>
          <Input.password_confirmation_field
            socket={@socket}
            strategy={@strategy}
            form={form}
            overrides={@overrides}
          />
        <% end %>

        <div class={override_for(@overrides, :spacer_class)}></div>

        <Input.submit
          socket={@socket}
          strategy={@strategy}
          form={form}
          action={:reset}
          disable_text={override_for(@overrides, :disable_button_text)}
          label={humanize(@resettable.password_reset_action_name)}
          overrides={@overrides}
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
    params = get_params(params, socket.assigns.strategy)

    form = Form.validate(socket.assigns.form, params)

    socket =
      socket
      |> assign(:form, form)
      |> assign(:trigger_action, form.valid?)

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
end
