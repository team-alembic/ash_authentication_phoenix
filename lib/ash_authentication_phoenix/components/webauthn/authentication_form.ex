# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.WebAuthn.AuthenticationForm do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the heading `h2` element (or `nil` to hide).",
    label_text: "Heading text (or `nil` to hide).",
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

  require Logger

  alias AshAuthentication.Info
  alias AshAuthentication.Phoenix.Components.WebAuthn

  import AshAuthentication.Phoenix.Components.Helpers,
    only: [auth_path: 6]

  import Slug

  @authentication_timeout_ms 60_000

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    # `send_update/2` (e.g. the timeout path in `WebAuthnLive`) only passes a
    # subset of assigns, so read everything through the merged socket assigns.
    socket = assign(socket, assigns)
    strategy = socket.assigns.strategy
    subject_name = Info.authentication_subject_name!(strategy.resource)

    socket =
      socket
      |> assign(:subject_name, subject_name)
      |> assign(:subject_name_slug, subject_name |> to_string() |> slugify())
      |> assign_new(:identity_value, fn -> "" end)
      |> assign_new(:error_message, fn -> nil end)
      |> assign_new(:submitting, fn -> false end)
      |> assign_new(:trigger_action, fn -> false end)
      |> assign_new(:sign_in_token, fn -> nil end)
      |> assign_new(:inner_block, fn -> nil end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:context, fn -> %{} end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    show_identity =
      assigns.strategy.require_identity? &&
        override_for(assigns.overrides, :show_identity_field, false)

    assigns = assign(assigns, :show_identity, show_identity)

    ~H"""
    <div class={override_for(@overrides, :root_class)} id={@id} phx-hook="WebAuthnAuthenticationHook">
      <%= if label_text = override_for(@overrides, :label_text) do %>
        <h2 class={override_for(@overrides, :label_class)}>{_gettext(label_text)}</h2>
      <% end %>
      <form
        id={"#{@id}-form"}
        phx-change="update-identity"
        phx-submit="authenticate"
        phx-target={@myself}
        class={override_for(@overrides, :form_class)}
      >
        <%= if @show_identity do %>
          <WebAuthn.Input.identity_field
            id={@id <> "-identity"}
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
      </form>

      <.form
        for={%{}}
        id={"#{@id}-token-form"}
        as={:user}
        action={
          auth_path(
            @socket,
            @subject_name_slug,
            @auth_routes_prefix,
            @strategy,
            :sign_in_with_token,
            %{}
          )
        }
        method="POST"
        phx-trigger-action={@trigger_action}
        style="display:none"
      >
        <input type="hidden" name="token" value={@sign_in_token || ""} />
      </.form>

      <%= if @inner_block do %>
        <div class={override_for(@overrides, :slot_class)}>
          {render_slot(@inner_block)}
        </div>
      <% end %>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("update-identity", params, socket) do
    identity_field_name = to_string(socket.assigns.strategy.identity_field)
    value = Map.get(params, identity_field_name, "")
    {:noreply, assign(socket, :identity_value, value)}
  end

  alias AshAuthentication.Phoenix.WebAuthn, as: PhoenixWebAuthn
  alias AshAuthentication.Strategy.WebAuthn

  def handle_event("authenticate", _params, socket) do
    strategy = socket.assigns.strategy
    tenant = socket.assigns.current_tenant
    origin = PhoenixWebAuthn.origin_from_socket(socket)

    {:ok, challenge} =
      WebAuthn.Actions.authentication_challenge(strategy, [], tenant, origin: origin)

    options = PhoenixWebAuthn.authentication_options(strategy, challenge, tenant, [])

    timer_ref = Process.send_after(self(), :authentication_timeout, @authentication_timeout_ms)

    socket =
      socket
      |> assign(:challenge, challenge)
      |> assign(:authentication_timer_ref, timer_ref)
      |> assign(:submitting, true)
      |> Phoenix.LiveView.push_event("authentication-challenge", options)

    {:noreply, socket}
  end

  def handle_event("authentication-assertion", params, socket) do
    socket = cancel_timer(socket)
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

    origin = PhoenixWebAuthn.origin_from_socket(socket)

    case WebAuthn.Actions.sign_in(
           strategy,
           sign_in_params,
           challenge: challenge,
           origin: origin,
           tenant: socket.assigns.current_tenant
         ) do
      {:ok, user} ->
        {:noreply,
         assign(socket,
           challenge: nil,
           sign_in_token: user.__metadata__.token,
           trigger_action: true
         )}

      {:error, error} ->
        Logger.error("WebAuthn authentication failed: #{inspect(error)}")

        {:noreply,
         assign(socket,
           challenge: nil,
           submitting: false,
           error_message: "Authentication failed. Please try again."
         )}
    end
  end

  def handle_event("authentication-error", %{"name" => name, "message" => message}, socket) do
    socket = cancel_timer(socket)

    error_msg =
      case name do
        "NotAllowedError" -> "The operation was cancelled or not allowed."
        _ -> message
      end

    {:noreply, assign(socket, challenge: nil, submitting: false, error_message: error_msg)}
  end

  defp cancel_timer(socket) do
    if timer_ref = socket.assigns[:authentication_timer_ref] do
      Process.cancel_timer(timer_ref)
      assign(socket, :authentication_timer_ref, nil)
    else
      socket
    end
  end
end
