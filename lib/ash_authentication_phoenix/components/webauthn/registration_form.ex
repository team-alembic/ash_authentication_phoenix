# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.WebAuthn.RegistrationForm do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    form_class: "CSS class for the `form` element.",
    button_text: "Text for the registration button.",
    disable_button_text: "Text shown while the registration ceremony is in progress.",
    slot_class: "CSS class for the `div` surrounding the slot."

  @moduledoc """
  Registration form for WebAuthn.

  Renders an identity input and a "Register with Passkey" button.
  On click, generates a challenge, pushes it to the JS hook,
  and handles the attestation response.

  On successful registration, redirects to the `sign_in_with_token` auth path
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
    ~H"""
    <div class={override_for(@overrides, :root_class)} id={@id} phx-hook="WebAuthnRegistrationHook">
      <div class={override_for(@overrides, :form_class)}>
        <WebAuthn.Input.identity_field
          identity_field={@strategy.identity_field}
          value={@identity_value}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />

        <WebAuthn.Input.register_button
          disabled={@submitting || @identity_value == ""}
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

  alias AshAuthentication.Strategy.WebAuthn

  def handle_event("register", _params, socket) do
    strategy = socket.assigns.strategy
    tenant = socket.assigns.current_tenant

    {:ok, challenge} = WebAuthn.Actions.registration_challenge(strategy, tenant)

    rp_id = WebAuthn.Helpers.resolve_rp_id(strategy, tenant)
    rp_name = WebAuthn.Helpers.resolve_rp_name(strategy, tenant)

    user_id = Base.url_encode64(:crypto.strong_rand_bytes(64), padding: false)

    socket =
      socket
      |> assign(:challenge, challenge)
      |> assign(:submitting, true)
      |> Phoenix.LiveView.push_event("registration-challenge", %{
        challenge: Base.url_encode64(challenge.bytes, padding: false),
        rp_id: rp_id,
        rp_name: rp_name,
        user_id: user_id,
        user_name: socket.assigns.identity_value,
        user_display_name: socket.assigns.identity_value,
        timeout: strategy.timeout,
        attestation: strategy.attestation,
        authenticator_attachment:
          if(strategy.authenticator_attachment,
            do: to_string(strategy.authenticator_attachment),
            else: nil
          ),
        user_verification: strategy.user_verification,
        resident_key: to_string(strategy.resident_key)
      })

    {:noreply, socket}
  end

  def handle_event("registration-attestation", params, socket) do
    strategy = socket.assigns.strategy
    challenge = socket.assigns.challenge

    register_params = %{
      to_string(strategy.identity_field) => socket.assigns.identity_value,
      "attestation_object" => params["attestation_object"],
      "client_data_json" => params["client_data_json"],
      "raw_id" => params["raw_id"]
    }

    case WebAuthn.Actions.register(
           strategy,
           register_params,
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
           error_message: "Registration failed. Please try again."
         )}
    end
  end

  def handle_event("registration-error", %{"name" => name, "message" => message}, socket) do
    error_msg =
      case name do
        "NotAllowedError" -> "The operation was cancelled or not allowed."
        "InvalidStateError" -> "This authenticator is already registered."
        _ -> message
      end

    {:noreply, assign(socket, challenge: nil, submitting: false, error_message: error_msg)}
  end
end
