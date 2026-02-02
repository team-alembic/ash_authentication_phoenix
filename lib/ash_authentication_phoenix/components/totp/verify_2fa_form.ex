# SPDX-FileCopyrightText: 2024 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Totp.Verify2faForm do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the `h2` element.",
    label_text: "Text for the form heading.",
    instructions_class: "CSS class for instructions text.",
    instructions_text: "Instructions text shown above the code input.",
    form_class: "CSS class for the `form` element.",
    slot_class: "CSS class for the `div` surrounding the slot.",
    button_text: "Text for the submit button.",
    disable_button_text: "Text for the submit button when the request is happening.",
    error_class: "CSS class for error messages.",
    sign_in_link_class: "CSS class for the sign-in link when not authenticated.",
    sign_in_link_text: "Text for the sign-in link."

  @moduledoc """
  Generates a verification form for TOTP two-factor authentication.

  This component supports two authentication flows:

  ## Token-based Flow (mode: :token)

  Used after primary authentication (e.g., password sign-in) when the user has
  TOTP enabled. The token contains partial authentication info that will be
  exchanged for a full session token after TOTP verification.

  ## Step-up Authentication Flow (mode: :step_up)

  Used when an already-authenticated user needs to verify their TOTP code to
  access protected resources. No token is required - uses the current_user
  from the session.

  ## Component hierarchy

  This is rendered by `AshAuthentication.Phoenix.TotpVerifyLive`.

  Children:

    * `AshAuthentication.Phoenix.Components.Totp.Input.code_field/1`
    * `AshAuthentication.Phoenix.Components.Totp.Input.submit/1`

  ## Props

    * `strategy` - The TOTP strategy configuration. Required.
    * `mode` - The verification mode: `:token`, `:step_up`, or `:error`. Required.
    * `token` - The partial authentication token (required for `:token` mode).
    * `current_user` - The authenticated user (required for `:step_up` mode).
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components.Totp, Strategy}
  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}

  import AshAuthentication.Phoenix.Components.Helpers,
    only: [auth_path: 5]

  import Phoenix.HTML.Form
  import Slug

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          required(:mode) => :token | :step_up | :error,
          optional(:token) => String.t(),
          optional(:current_user) => map(),
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
    strategy = assigns[:strategy]
    resource = assigns[:resource]

    socket =
      socket
      |> assign(assigns)
      |> assign(trigger_action: false)
      |> assign_new(:inner_block, fn -> nil end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:context, fn -> %{} end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)
      |> assign_new(:token, fn -> nil end)
      |> assign_new(:mode, fn -> :error end)
      |> assign_new(:current_user, fn -> nil end)
      |> assign_new(:error, fn -> nil end)

    socket =
      if strategy && resource do
        subject_name = Info.authentication_subject_name!(resource)
        domain = Info.authentication_domain!(resource)

        context =
          Ash.Helpers.deep_merge_maps(assigns[:context] || %{}, %{
            strategy: strategy,
            private: %{ash_authentication?: true}
          })

        form =
          resource
          |> Form.for_action(strategy.verify_action_name,
            domain: domain,
            as: subject_name |> to_string() |> slugify(),
            id:
              "#{subject_name}-#{Strategy.name(strategy)}-verify-2fa"
              |> slugify(),
            tenant: assigns[:current_tenant],
            context: context
          )

        socket
        |> assign(form: form, subject_name: subject_name)
      else
        assign(socket, form: nil, subject_name: nil)
      end

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <h2 class={override_for(@overrides, :label_class)}>
        {_gettext(override_for(@overrides, :label_text))}
      </h2>

      <p class={override_for(@overrides, :instructions_class)}>
        {_gettext(override_for(@overrides, :instructions_text))}
      </p>

      <%= if @error do %>
        <div class={override_for(@overrides, :error_class)}>
          {_gettext(@error)}
        </div>
      <% end %>

      <%= case @mode do %>
        <% :error -> %>
          <p class={override_for(@overrides, :error_class)}>
            {_gettext("You must be signed in to verify your authentication code.")}
          </p>
          <a href="/sign-in" class={override_for(@overrides, :sign_in_link_class)}>
            {_gettext(override_for(@overrides, :sign_in_link_text, "Sign in"))}
          </a>
        <% mode when mode in [:token, :step_up] -> %>
          <%= if @form && @strategy do %>
            <.form
              :let={form}
              for={@form}
              id={@form.id}
              phx-change="change"
              phx-submit="submit"
              phx-trigger-action={@trigger_action}
              phx-target={@myself}
              action={auth_path(@socket, @subject_name, @auth_routes_prefix, @strategy, :verify)}
              method="POST"
              class={override_for(@overrides, :form_class)}
            >
              <%= if @mode == :token do %>
                <input type="hidden" name={input_name(form, :token)} value={@token} />
              <% end %>

              <Totp.Input.code_field
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

              <Totp.Input.submit
                strategy={@strategy}
                id={@form.id <> "-submit"}
                form={form}
                action={:verify}
                label={override_for(@overrides, :button_text)}
                disable_text={override_for(@overrides, :disable_button_text)}
                overrides={@overrides}
                gettext_fn={@gettext_fn}
              />
            </.form>
          <% else %>
            <p class={override_for(@overrides, :error_class)}>
              {_gettext("Unable to load verification form.")}
            </p>
          <% end %>
      <% end %>
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

    params =
      case socket.assigns.mode do
        :token -> Map.put(params, "token", socket.assigns.token)
        :step_up -> params
        _ -> params
      end

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
