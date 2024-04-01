defmodule AshAuthentication.Phoenix.Components.Password.RegisterForm do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the `h2` element.",
    form_class: "CSS class for the `form` element.",
    slot_class: "CSS class for the `div` surrounding the slot.",
    disable_button_text: "Text for the submit button when the request is happening."

  @moduledoc """
  Generates a default registration form.

  ## Component hierarchy

  This is a child of `AshAuthentication.Phoenix.Components.Password`.

  Children:

    * `AshAuthentication.Phoenix.Components.Password.Input.identity_field/1`
    * `AshAuthentication.Phoenix.Components.Password.Input.password_field/1`
    * `AshAuthentication.Phoenix.Components.Password.Input.password_confirmation_field/1`
    * `AshAuthentication.Phoenix.Components.Password.Input.submit/1`

  ## Props

    * `strategy` - The strategy configuration as per
      `AshAuthentication.Info.strategy/2`.  Required.
    * `socket` - Needed to infer the otp-app from the Phoenix endpoint.
    * `overrides` - A list of override modules.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component

  alias AshAuthentication.{Info, Phoenix.Components.Password.Input, Strategy}
  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}

  import PhoenixHTMLHelpers.Form
  import AshAuthentication.Phoenix.Components.Helpers
  import Slug

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          optional(:overrides) => [module],
          optional(:live_action) => :sign_in | :register,
          optional(:current_tenant) => String.t()
        }

  @doc false
  @impl true
  @spec update(props, Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    strategy = assigns.strategy

    api = Info.authentication_domain!(strategy.resource)
    subject_name = Info.authentication_subject_name!(strategy.resource)

    form =
      strategy.resource
      |> Form.for_action(strategy.register_action_name,
        api: api,
        as: subject_name |> to_string(),
        id:
          "#{subject_name}-#{Strategy.name(strategy)}-#{strategy.register_action_name}"
          |> slugify(),
        context: %{strategy: strategy, private: %{ash_authentication?: true}}
      )

    socket =
      socket
      |> assign(assigns)
      |> assign(
        form: form,
        trigger_action: false,
        subject_name: subject_name
      )
      |> assign_new(:label, fn -> humanize(strategy.register_action_name) end)
      |> assign_new(:inner_block, fn -> nil end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:current_tenant, fn -> nil end)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= if @label do %>
        <h2 class={override_for(@overrides, :label_class)}>
          <%= @label %>
        </h2>
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
            {@subject_name, Strategy.name(@strategy), :register}
          )
        }
        method="POST"
        class={override_for(@overrides, :form_class)}
      >
        <Input.identity_field strategy={@strategy} form={form} overrides={@overrides} />
        <Input.password_field strategy={@strategy} form={form} overrides={@overrides} />

        <%= if @strategy.confirmation_required? do %>
          <Input.password_confirmation_field strategy={@strategy} form={form} overrides={@overrides} />
        <% end %>

        <%= if @inner_block do %>
          <div class={override_for(@overrides, :slot_class)}>
            <%= render_slot(@inner_block, form) %>
          </div>
        <% end %>

        <Input.submit
          strategy={@strategy}
          form={form}
          action={:register}
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
    params = get_params(params, socket.assigns.strategy)

    if Map.get(socket.assigns.strategy, :sign_in_tokens_enabled?) do
      case Form.submit(socket.assigns.form,
             params: params,
             read_one?: true,
             before_submit: fn changeset ->
               changeset
               |> Ash.Changeset.set_context(%{token_type: :sign_in})
               |> Ash.Changeset.set_tenant(socket.assigns.current_tenant)
             end
           ) do
        {:ok, user} ->
          validate_sign_in_token_path =
            route_helpers(socket).auth_path(
              socket.endpoint,
              {socket.assigns.subject_name, Strategy.name(socket.assigns.strategy),
               :sign_in_with_token},
              token: user.__metadata__.token
            )

          {:noreply, redirect(socket, to: validate_sign_in_token_path)}

        {:error, form} ->
          {:noreply,
           assign(socket, :form, Form.clear_value(form, socket.assigns.strategy.password_field))}
      end
    else
      form = Form.validate(socket.assigns.form, params)

      socket =
        socket
        |> assign(:form, form)
        |> assign(:trigger_action, form.valid?)

      {:noreply, socket}
    end
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
