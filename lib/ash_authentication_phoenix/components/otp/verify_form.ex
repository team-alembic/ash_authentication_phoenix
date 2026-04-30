# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Otp.VerifyForm do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the `h2` element.",
    form_class: "CSS class for the `form` element.",
    description_class: "CSS class for the description paragraph.",
    description_text:
      "Text shown above the OTP code field, e.g. \"Enter the code we sent you.\". Set to `nil` to disable.",
    disable_button_text: "Text for the submit button when the request is happening.",
    back_link_class: "CSS class for the back link.",
    back_link_text: "Text for the link that returns to the request form. Set to `nil` to disable."

  @moduledoc """
  Generates the form for verifying an OTP code (step two of the OTP flow).

  The form posts directly to the strategy's sign-in endpoint via
  `phx-trigger-action` so the JWT lands in the session through the standard
  `AuthController` pipeline.

  ## Component hierarchy

  This is a child of `AshAuthentication.Phoenix.Components.Otp`.

  Children:

    * `AshAuthentication.Phoenix.Components.Otp.Input.code_field/1`
    * `AshAuthentication.Phoenix.Components.Otp.Input.submit/1`

  ## Props

    * `strategy` - The OTP strategy configuration. Required.
    * `identity` - The identity value (e.g. email address) submitted in the
      request phase. Pre-filled into a hidden field on the verify form.
      Required.
    * `parent_id` - The ID of the parent `Components.Otp` LiveComponent.
      Required.
    * `auth_routes_prefix` - Optional prefix for authentication routes.
    * `label` - Text to show in the `h2` heading. `false` to disable.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component

  alias AshAuthentication.{
    Info,
    Phoenix.Components.Otp,
    Strategy
  }

  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}
  import AshAuthentication.Phoenix.Components.Helpers, only: [auth_path: 5]
  import PhoenixHTMLHelpers.Form
  import Slug

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          required(:identity) => String.t(),
          required(:parent_id) => String.t(),
          optional(:auth_routes_prefix) => String.t(),
          optional(:label) => String.t() | false,
          optional(:current_tenant) => String.t(),
          optional(:context) => map(),
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }

  @doc false
  @impl true
  @spec update(props, Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    strategy = assigns.strategy
    subject_name = Info.authentication_subject_name!(strategy.resource)

    socket =
      socket
      |> assign(assigns)
      |> assign(trigger_action: false, subject_name: subject_name)
      |> assign_new(:label, fn -> humanize(strategy.sign_in_action_name) end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:context, fn -> %{} end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)

    form =
      strategy.resource
      |> Form.for_action(strategy.sign_in_action_name,
        domain: Info.authentication_domain!(strategy.resource),
        as: subject_name |> to_string(),
        id:
          "#{subject_name}-#{Strategy.name(strategy)}-#{strategy.sign_in_action_name}"
          |> slugify(),
        tenant: socket.assigns.current_tenant,
        transform_errors: _transform_errors(),
        params: %{to_string(strategy.identity_field) => assigns[:identity]},
        context:
          Ash.Helpers.deep_merge_maps(socket.assigns[:context] || %{}, %{
            strategy: strategy,
            private: %{ash_authentication?: true}
          })
      )

    socket = assign(socket, form: form)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(props) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <h2 :if={@label} class={override_for(@overrides, :label_class)}>{_gettext(@label)}</h2>

      <p
        :if={override_for(@overrides, :description_text)}
        class={override_for(@overrides, :description_class)}
      >
        {_gettext(override_for(@overrides, :description_text))}
      </p>

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
        {hidden_input(form, @strategy.identity_field, value: @identity)}

        <Otp.Input.code_field
          strategy={@strategy}
          form={form}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />

        <Otp.Input.submit
          strategy={@strategy}
          form={form}
          action={:verify}
          disable_text={_gettext(override_for(@overrides, :disable_button_text))}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />

        <a
          :if={override_for(@overrides, :back_link_text)}
          href="#"
          phx-click="back"
          phx-target={@myself}
          class={override_for(@overrides, :back_link_class)}
        >
          {_gettext(override_for(@overrides, :back_link_text))}
        </a>
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

  def handle_event("back", _params, socket) do
    send_update(AshAuthentication.Phoenix.Components.Otp,
      id: socket.assigns.parent_id,
      event: :reset_to_request
    )

    {:noreply, socket}
  end

  defp get_params(params, strategy) do
    param_key =
      strategy.resource
      |> Info.authentication_subject_name!()
      |> to_string()

    Map.get(params, param_key, %{})
  end
end
