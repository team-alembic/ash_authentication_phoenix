# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Otp.RequestForm do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the `h2` element.",
    form_class: "CSS class for the `form` element.",
    disable_button_text: "Text for the submit button when the request is happening.",
    request_flash_text:
      "Text for the flash message shown after the OTP request is submitted. Set to `nil` to disable."

  @moduledoc """
  Generates the form for requesting an OTP code (step one of the OTP flow).

  On successful submission this component runs the request action server-side
  (which fires the configured sender) and notifies the parent
  `AshAuthentication.Phoenix.Components.Otp` component to advance to the
  verify phase.

  ## Component hierarchy

  This is a child of `AshAuthentication.Phoenix.Components.Otp`.

  Children:

    * `AshAuthentication.Phoenix.Components.Otp.Input.identity_field/1`
    * `AshAuthentication.Phoenix.Components.Otp.Input.submit/1`

  ## Props

    * `strategy` - The OTP strategy configuration. Required.
    * `parent_id` - The ID of the parent `Components.Otp` LiveComponent.
      Required (used for `send_update`).
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
  import AshAuthentication.Phoenix.Components.Helpers, only: [debug_form_errors: 1]
  import PhoenixHTMLHelpers.Form
  import Slug

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          required(:parent_id) => String.t(),
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
      |> assign(:subject_name, subject_name)
      |> assign_new(:label, fn -> humanize(strategy.request_action_name) end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:context, fn -> %{} end)
      |> assign_new(:form, fn -> blank_form(strategy, assigns[:context] || %{}, assigns) end)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(props) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <h2 :if={@label} class={override_for(@overrides, :label_class)}>{_gettext(@label)}</h2>

      <.form
        :let={form}
        for={@form}
        id={@form.id}
        phx-change="change"
        phx-submit="submit"
        phx-target={@myself}
        class={override_for(@overrides, :form_class)}
      >
        <Otp.Input.identity_field
          strategy={@strategy}
          form={form}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />

        <Otp.Input.submit
          strategy={@strategy}
          form={form}
          action={:request}
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

    case Form.submit(socket.assigns.form, params: params) do
      :ok ->
        notify_parent(socket, params)
        flash_request_message(socket)

      {:ok, _result} ->
        notify_parent(socket, params)
        flash_request_message(socket)

      {:error, form} ->
        debug_form_errors(form)
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(socket, params) do
    identity_field = socket.assigns.strategy.identity_field
    identity_value = Map.get(params, to_string(identity_field)) || Map.get(params, identity_field)

    send_update(AshAuthentication.Phoenix.Components.Otp,
      id: socket.assigns.parent_id,
      event: :request_succeeded,
      identity: identity_value
    )
  end

  defp flash_request_message(socket) do
    flash = override_for(socket.assigns.overrides, :request_flash_text)

    socket =
      if flash do
        socket |> put_flash!(:info, _gettext(flash))
      else
        socket
      end

    socket =
      assign(
        socket,
        :form,
        blank_form(socket.assigns.strategy, socket.assigns[:context] || %{}, socket.assigns)
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

  defp blank_form(strategy, context, assigns) do
    domain = Info.authentication_domain!(strategy.resource)
    subject_name = Info.authentication_subject_name!(strategy.resource)

    strategy.resource
    |> Form.for_action(strategy.request_action_name,
      domain: domain,
      as: subject_name |> to_string(),
      id:
        "#{subject_name}-#{Strategy.name(strategy)}-#{strategy.request_action_name}"
        |> slugify(),
      tenant: assigns[:current_tenant],
      transform_errors: _transform_errors(),
      context:
        Ash.Helpers.deep_merge_maps(context, %{
          strategy: strategy,
          private: %{ash_authentication?: true}
        })
    )
  end
end
