# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Password.ResetForm do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the `h2` element.",
    form_class: "CSS class for the `form` element.",
    slot_class: "CSS class for the `div` surrounding the slot.",
    button_text: "Tex for the submit button.",
    disable_button_text: "Text for the submit button when the request is happening.",
    reset_flash_text:
      "Text for the flash message when a request is received.  Set to `nil` to disable."

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
      configured action name (via `Phoenix.Naming.humanize/1`) if not supplied.
      Set to `false` to disable.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component

  alias AshAuthentication.{Info, Phoenix.Components.Password.Input, Strategy}

  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}
  import AshAuthentication.Phoenix.Components.Helpers
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

    socket =
      socket
      |> assign(assigns)
      |> assign(subject_name: Info.authentication_subject_name!(strategy.resource))
      |> assign_new(:label, fn -> strategy.request_password_reset_action_name end)
      |> assign_new(:inner_block, fn -> nil end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:context, fn -> nil end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)

    form = blank_form(strategy, assigns[:context] || %{}, socket)

    {:ok, assign(socket, form: form)}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= if @label do %>
        <h2 class={override_for(@overrides, :label_class)}>
          {@label}
        </h2>
      <% end %>

      <.form
        :let={form}
        for={@form}
        phx-submit="submit"
        phx-change="change"
        phx-target={@myself}
        action={
          auth_path(
            @socket,
            @subject_name,
            @auth_routes_prefix,
            @strategy,
            :reset_request
          )
        }
        method="POST"
        class={override_for(@overrides, :form_class)}
      >
        <Input.identity_field
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

        <Input.submit
          strategy={@strategy}
          form={form}
          action={:request_reset}
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
    strategy = socket.assigns.strategy
    params = get_params(params, strategy)

    socket.assigns.form
    |> Form.validate(params)
    |> Form.submit(params: params)
    |> case do
      {:error, form} ->
        debug_form_errors(form)

      _ ->
        :ok
    end

    flash = override_for(socket.assigns.overrides, :reset_flash_text)

    socket =
      socket
      |> assign(:form, blank_form(strategy, socket.assigns[:context] || %{}, socket))

    socket =
      if flash do
        socket
        |> put_flash!(:info, _gettext(flash))
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

  defp blank_form(%{resettable: resettable} = strategy, context, socket)
       when not is_nil(resettable) do
    domain = Info.authentication_domain!(strategy.resource)
    subject_name = Info.authentication_subject_name!(strategy.resource)

    strategy.resource
    |> Form.for_action(resettable.request_password_reset_action_name,
      domain: domain,
      as: subject_name |> to_string(),
      transform_errors: _transform_errors(),
      tenant: socket.assigns.current_tenant,
      id:
        "#{subject_name}-#{Strategy.name(strategy)}-#{resettable.request_password_reset_action_name}"
        |> slugify(),
      context:
        Ash.Helpers.deep_merge_maps(context, %{
          strategy: strategy,
          private: %{ash_authentication?: true}
        })
    )
  end
end
