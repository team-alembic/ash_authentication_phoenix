# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.MagicLink.Form do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for root `div` element.",
    label_class: "CSS class for the `h2` element.",
    form_class: "CSS class for the `form` element.",
    disable_button_text: "Text for the submit button when the request is happening."

  @moduledoc """
  Generates a default magic sign in form.

  ## Component heirarchy

  This is a child of `AshAuthentication.Phoenix.Components.MagicLink.SignIn`.

  Children:

    * `AshAuthentication.Phoenix.Components.MagicLink.Input.submit/1`.

  ## Props

    * `token` - The magic sign in token.
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
  alias AshAuthentication.{Info, Phoenix.Components.MagicLink.Input, Strategy}
  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}
  import AshAuthentication.Phoenix.Components.Helpers, only: [auth_path: 5]
  import PhoenixHTMLHelpers.Form
  import Slug

  @doc false
  @impl true
  @spec update(map, Socket.t()) :: {:ok, Socket.t()}
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
      |> Form.for_action(strategy.sign_in_action_name,
        transform_errors: _transform_errors(),
        domain: domain,
        as: subject_name |> to_string(),
        tenant: socket.assigns.current_tenant,
        id:
          "#{subject_name}-#{Strategy.name(strategy)}-#{strategy.sign_in_action_name}"
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
      <h2 :if={@label} class={override_for(@overrides, :label_class)}>{_gettext(@label)}</h2>

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
            :sign_in
          )
        }
        method="POST"
        class={override_for(@overrides, :form_class)}
      >
        <input type="hidden" name="token" value={@token} />

        <Input.submit
          strategy={@strategy}
          form={form}
          action={@strategy.sign_in_action_name}
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
    form = Form.validate(socket.assigns.form, params)

    socket =
      socket
      |> assign(:form, form)
      |> assign(:trigger_action, true)

    {:noreply, socket}
  end
end
