# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.WebAuthn.AuthenticationForm do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    form_class: "CSS class for the `form` element.",
    button_text: "Text for the authentication button.",
    disable_button_text: "Text shown while the authentication ceremony is in progress.",
    slot_class: "CSS class for the `div` surrounding the slot.",
    show_identity_field:
      "Whether to show the identity input (false for discoverable credentials)."

  @moduledoc """
  Authentication form for WebAuthn.

  Renders a "Sign in with Passkey" button. Optionally shows an identity input
  for non-discoverable credentials.

  Supports conditional UI (passkey autofill) when the browser supports it
  and `show_identity_field` is true — the identity input gets
  `autocomplete="username webauthn"` which triggers browser autofill.

  On successful authentication, redirects to the `sign_in_with_token` auth path
  (matching the existing auth completion flow used by Password.SignInForm).

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components.WebAuthn}
  # alias Phoenix.LiveView.{Rendered, Socket}

  import AshAuthentication.Phoenix.Components.Helpers,
    only: [auth_path: 6]

  import Slug

  @impl true
  def update(assigns, socket) do
    strategy = assigns.strategy
    subject_name = Info.authentication_subject_name!(strategy.resource)

    socket =
      socket
      |> assign(assigns)
      |> assign(:subject_name, subject_name)
      |> assign(:subject_name_slug, subject_name |> to_string() |> slugify())
      |> assign_new(:identity_value, fn -> "" end)
      |> assign_new(:error_message, fn -> nil end)
      |> assign_new(:submitting, fn -> false end)
      |> assign_new(:inner_block, fn -> nil end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:context, fn -> %{} end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    show_identity = override_for(assigns.overrides, :show_identity_field, false)
    assigns = assign(assigns, :show_identity, show_identity)

    ~H"""
    <div class={override_for(@overrides, :root_class)} id={@id} phx-hook="WebAuthnAuthenticationHook">
      <div class={override_for(@overrides, :form_class)}>
        <%= if @show_identity do %>
          <WebAuthn.Input.identity_field
            identity_field={@strategy.identity_field}
            value={@identity_value}
            overrides={@overrides}
            gettext_fn={@gettext_fn}
          />
        <% end %>

        <WebAuthn.Input.sign_in_button
          disabled={@submitting}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />

        <WebAuthn.Input.error
          message={@error_message}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />
      </div>

      <%= if @inner_block do %>
        <div class={override_for(@overrides, :slot_class)}>
          {render_slot(@inner_block)}
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("update-identity", %{"value" => value}, socket) do
    {:noreply, assign(socket, :identity_value, value)}
  end

  def handle_event("authenticate", _params, socket) do
    strategy = socket.assigns.strategy
    tenant = socket.assigns.current_tenant

    {:ok, challenge} =
      AshAuthentication.Strategy.WebAuthn.Actions.authentication_challenge(strategy, [], tenant)

    rp_id = AshAuthentication.Strategy.WebAuthn.Helpers.resolve_rp_id(strategy, tenant)

    socket =
      socket
      |> assign(:challenge, challenge)
      |> assign(:submitting, true)
      |> Phoenix.LiveView.push_event("authentication-challenge", %{
        challenge: Base.url_encode64(challenge.bytes, padding: false),
        rp_id: rp_id,
        timeout: strategy.timeout,
        user_verification: strategy.user_verification,
        allow_credentials: []
      })

    {:noreply, socket}
  end

  def handle_event("authentication-assertion", params, socket) do
    strategy = socket.assigns.strategy
    challenge = socket.assigns.challenge

    sign_in_params = %{
      to_string(strategy.identity_field) => socket.assigns.identity_value,
      "raw_id" => params["raw_id"],
      "authenticator_data" => params["authenticator_data"],
      "signature" => params["signature"],
      "client_data_json" => params["client_data_json"],
      "user_handle" => params["user_handle"]
    }

    case AshAuthentication.Strategy.WebAuthn.Actions.sign_in(
           strategy,
           sign_in_params,
           challenge: challenge,
           tenant: socket.assigns.current_tenant
         ) do
      {:ok, user} ->
        subject_name_slug = socket.assigns.subject_name_slug

        redirect_path =
          auth_path(
            socket,
            subject_name_slug,
            socket.assigns.auth_routes_prefix,
            strategy,
            :sign_in_with_token,
            %{token: user.__metadata__.token}
          )

        {:noreply, socket |> assign(:challenge, nil) |> redirect(to: redirect_path)}

      {:error, _error} ->
        {:noreply,
         assign(socket,
           challenge: nil,
           submitting: false,
           error_message: "Authentication failed. Please try again."
         )}
    end
  end

  def handle_event("authentication-error", %{"name" => name, "message" => message}, socket) do
    error_msg =
      case name do
        "NotAllowedError" -> "The operation was cancelled or not allowed."
        _ -> message
      end

    {:noreply, assign(socket, challenge: nil, submitting: false, error_message: error_msg)}
  end
end
