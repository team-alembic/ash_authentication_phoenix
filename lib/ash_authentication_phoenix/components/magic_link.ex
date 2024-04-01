defmodule AshAuthentication.Phoenix.Components.MagicLink do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the `h2` element.",
    form_class: "CSS class for the `form` element.",
    request_flash_text:
      "Text for the flash message when a request is received.  Set to `nil` to disable.",
    disable_button_text: "Text for the submit button when the request is happening."

  @moduledoc """
  Generates a sign-in for for a resource using the "Magic link" strategy.

  ## Component hierarchy

  This is the top-most strategy-specific component, nested below
  `AshAuthentication.Phoenix.Components.SignIn`.

  Children:

    * `AshAuthentication.Phoenix.Components.Password.Input.identity_field/1`
    * `AshAuthentication.Phoenix.Components.Password.Input.submit/1`

  ## Props

    * `strategy` - the strategy configuration as per
      `AshAuthentication.Info.strategy/2`.  Required.
    * `overrides` - A list of override modules.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components.Password.Input, Strategy}
  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}
  import AshAuthentication.Phoenix.Components.Helpers, only: [route_helpers: 1]
  import Slug

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          optional(:overrides) => [module],
          optional(:current_tenant) => String.t()
        }

  @doc false
  @impl true
  @spec update(props, Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    strategy = assigns.strategy
    subject_name = Info.authentication_subject_name!(strategy.resource)

    form = blank_form(strategy)

    socket =
      socket
      |> assign(assigns)
      |> assign(form: form, trigger_action: false, subject_name: subject_name)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:label, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(props) :: Rendered.t() | no_return
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
            {@subject_name, Strategy.name(@strategy), :request}
          )
        }
        method="POST"
        class={override_for(@overrides, :form_class)}
      >
        <Input.identity_field strategy={@strategy} form={form} overrides={@overrides} />

        <Input.submit
          strategy={@strategy}
          form={form}
          action={@strategy.request_action_name}
          disable_text={override_for(@overrides, :disable_button_text)}
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
    strategy = socket.assigns.strategy
    params = get_params(params, strategy)

    socket.assigns.form
    |> Form.validate(params)
    |> Form.submit(
      before_submit: fn changeset ->
        changeset
        |> Ash.Changeset.set_tenant(socket.assigns.current_tenant)
      end
    )

    flash = override_for(socket.assigns.overrides, :request_flash_text)

    socket =
      socket
      |> assign(:form, blank_form(strategy))

    socket =
      if flash do
        socket
        |> put_flash!(:info, flash)
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

  defp blank_form(strategy) do
    api = Info.authentication_domain!(strategy.resource)
    subject_name = Info.authentication_subject_name!(strategy.resource)

    strategy.resource
    |> Form.for_action(strategy.request_action_name,
      api: api,
      as: subject_name |> to_string(),
      id:
        "#{subject_name}-#{Strategy.name(strategy)}-#{strategy.request_action_name}" |> slugify(),
      context: %{strategy: strategy, private: %{ash_authentication?: true}}
    )
  end
end
