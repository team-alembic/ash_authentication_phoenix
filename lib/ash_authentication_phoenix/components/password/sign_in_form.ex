# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Password.SignInForm do
  alias AshAuthentication.Phoenix.Components.Helpers

  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the `h2` element.",
    form_class: "CSS class for the `form` element.",
    slot_class: "CSS class for the `div` surrounding the slot.",
    button_text: "Text for the submit button.",
    disable_button_text: "Text for the submit button when the request is happening."

  @moduledoc """
  Generates a default sign in form.

  ## Component hierarchy

  This is a child of `AshAuthentication.Phoenix.Components.Password`.

  Children:

    * `AshAuthentication.Phoenix.Components.Password.Input.identity_field/1`
    * `AshAuthentication.Phoenix.Components.Password.Input.password_field/1`
    * `AshAuthentication.Phoenix.Components.Password.Input.submit/1`

  ## Props

    * `strategy` - The configuration map as per
      `AshAuthentication.Info.strategy/2`. Required.
    * `label` - The text to show in the submit label. Generated from the
      configured action name (via `Phoenix.Naming.humanize/1`) if not supplied.
      Set to `false` to disable.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components.Password, Strategy}
  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}

  import AshAuthentication.Phoenix.Components.Helpers,
    only: [auth_path: 5, auth_path: 6, debug_form_errors: 1]

  import PhoenixHTMLHelpers.Form
  import Slug

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          optional(:label) => String.t() | false,
          optional(:current_tenant) => String.t(),
          optional(:context) => map(),
          optional(:auth_routes_prefix) => String.t(),
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }

  @doc false
  @impl true
  @spec update(props, Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    strategy = assigns.strategy
    domain = Info.authentication_domain!(strategy.resource)
    subject_name = Info.authentication_subject_name!(strategy.resource)

    socket =
      socket
      |> assign(assigns)
      |> assign(trigger_action: false, subject_name: subject_name)
      |> assign_new(:label, fn -> humanize(strategy.sign_in_action_name) end)
      |> assign_new(:inner_block, fn -> nil end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:context, fn -> %{} end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)
      |> assign_new(:remember_me_field, fn -> Helpers.remember_me_field(assigns.strategy) end)

    context =
      Ash.Helpers.deep_merge_maps(assigns[:context] || %{}, %{
        strategy: strategy,
        private: %{ash_authentication?: true}
      })

    context =
      if Map.get(socket.assigns.strategy, :sign_in_tokens_enabled?) do
        Map.put(context, :token_type, :sign_in)
      else
        context
      end

    form =
      strategy.resource
      |> Form.for_action(strategy.sign_in_action_name,
        domain: domain,
        as: subject_name |> to_string() |> slugify(),
        id:
          "#{subject_name}-#{Strategy.name(strategy)}-#{strategy.sign_in_action_name}"
          |> slugify(),
        tenant: assigns[:current_tenant],
        transform_errors: _transform_errors(),
        context: context
      )

    socket = assign(socket, form: form, trigger_action: false, subject_name: subject_name)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= if @label do %>
        <h2 class={override_for(@overrides, :label_class)}>{_gettext(@label)}</h2>
      <% end %>

      <.form
        :let={form}
        for={@form}
        id={@form.id}
        phx-change="change"
        phx-submit="submit"
        phx-trigger-action={@trigger_action}
        phx-target={@myself}
        action={auth_path(@socket, @subject_name, @auth_routes_prefix, @strategy, :sign_in)}
        method="POST"
        class={override_for(@overrides, :form_class)}
      >
        <Password.Input.identity_field
          strategy={@strategy}
          form={form}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />
        <Password.Input.password_field
          strategy={@strategy}
          form={form}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />
        <%= if @inner_block do %>
          <div class={override_for(@overrides, :slot_class)}>
            {render_slot(@inner_block, form)}
          </div>
        <% end %>

        <Password.Input.remember_me_field
          :if={@remember_me_field}
          name={@remember_me_field}
          form={form}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />

        <Password.Input.submit
          strategy={@strategy}
          id={@form.id <> "-submit"}
          form={form}
          action={:sign_in}
          label={override_for(@overrides, :button_text)}
          disable_text={override_for(@overrides, :disable_button_text)}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
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
             read_one?: true
           ) do
        {:ok, user} ->
          auth_path_params = get_auth_path_params(params, user)

          validate_sign_in_token_path =
            auth_path(
              socket,
              socket.assigns.subject_name,
              socket.assigns.auth_routes_prefix,
              socket.assigns.strategy,
              :sign_in_with_token,
              auth_path_params
            )

          {:noreply, redirect(socket, to: validate_sign_in_token_path)}

        {:error, form} ->
          debug_form_errors(form)

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

  defp get_auth_path_params(params, user) do
    case Map.get(params, "remember_me") do
      nil -> %{token: user.__metadata__.token}
      remember_me -> %{token: user.__metadata__.token, remember_me: remember_me}
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
