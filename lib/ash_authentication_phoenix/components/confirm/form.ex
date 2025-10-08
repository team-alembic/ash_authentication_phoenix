# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Confirm.Form do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the `h2` element.",
    form_class: "CSS class for the `form` element.",
    disable_button_text: "Text for the submit button when the request is happening."

  @moduledoc """
  Generates a default confirmation form.

  ## Component hierarchy

  This is a child of `AshAuthentication.Phoenix.Components.Confirm`.

  Children:

    * `AshAuthentication.Phoenix.Components.Confirm.Input.submit/1`

  ## Props

    * `token` - The confirmation token.
    * `socket` - Phoenix LiveView socket.  This is needed to be able to retrieve
      the correct CSS configuration. Required.
    * `strategy` - The configuration map as per
      `AshAuthentication.Info.strategy/2`. Required.
    * `label` - The text to show in the submit label. Generated from the
      strategy name (via `Phoenix.Naming.humanize/1`) if not
      supplied. Set to `false` to disable.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components.Confirm.Input, Strategy}
  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}
  import AshAuthentication.Phoenix.Components.Helpers, only: [auth_path: 5]
  import PhoenixHTMLHelpers.Form
  import Slug

  @type props :: %{
          required(:socket) => Socket.t(),
          required(:strategy) => AshAuthentication.Strategy.t(),
          required(:token) => String.t(),
          optional(:label) => String.t() | false,
          optional(:auth_routes_prefix) => String.t(),
          optional(:overrides) => [module],
          optional(:current_tenant) => term(),
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
      |> assign(
        trigger_action: false,
        subject_name: subject_name,
        strategy: strategy
      )
      |> assign_new(:label, fn -> humanize(strategy.name) end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)

    form =
      strategy.resource
      |> Form.for_action(strategy.confirm_action_name,
        transform_errors: _transform_errors(),
        domain: domain,
        as: subject_name |> to_string(),
        tenant: socket.assigns.current_tenant,
        id:
          "#{subject_name}-#{Strategy.name(strategy)}-#{strategy.confirm_action_name}"
          |> slugify(),
        context: %{strategy: strategy, private: %{ash_authentication?: true}}
      )

    socket = assign(socket, form: form)

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
        phx-submit="submit"
        phx-trigger-action={@trigger_action}
        phx-target={@myself}
        action={
          auth_path(
            @socket,
            @subject_name,
            @auth_routes_prefix,
            @strategy,
            :confirm
          )
        }
        method="POST"
        class={override_for(@overrides, :form_class)}
      >
        {hidden_input(form, :confirm, value: @token)}

        <Input.submit
          strategy={@strategy}
          form={form}
          action={:confirm}
          disable_text={_gettext(override_for(@overrides, :disable_button_text))}
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

  def handle_event("submit", params, socket) do
    params = get_params(params, socket.assigns.strategy)

    form = Form.validate(socket.assigns.form, params)

    socket =
      socket
      |> assign(:form, form)
      |> assign(:trigger_action, true)

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
