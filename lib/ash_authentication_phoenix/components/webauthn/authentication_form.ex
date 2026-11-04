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
      "Whether to show an optional identity input above the sign-in button. Sign-in never needs one — the browser offers the discoverable passkeys it holds for the site and the credential resolves the user — and a submitted identity is only checked against the credential's owner. Defaults to `false`; never shown when the strategy requires no identity.",
    timeout_text: "Error shown when the browser does not answer within the strategy's `timeout`.",
    expired_text:
      "Error shown when an assertion arrives for a ceremony that has already timed out."

  @moduledoc """
  Authentication form for WebAuthn.

  Renders a "Sign in with Passkey" button. Every sign-in is a
  discoverable-credential sign-in: the challenge lists no credentials (it
  is issued before anyone is authenticated, and a submitted identity's
  credential ids must not be disclosed), the browser offers the passkeys it
  holds for the site, and the credential id resolves the user. The form
  therefore never asks for an identity in order to find a passkey, and
  only discoverable credentials (`resident_key :required`, the strategy's
  default) can sign in.

  With `show_identity_field` on, and a strategy that requires an identity,
  an optional identity input is rendered. Its value is submitted with the
  assertion and must match the credential's owner; that is all it is used
  for. The input carries `autocomplete="username webauthn"`, the token the
  browser's passkey autofill (conditional UI) keys on. The JS hook also
  listens for an `authentication-challenge-conditional` event for a
  conditional-mediation ceremony.

  ## Cross-device sign-in

  When the strategy offers the `:hybrid` hint, or allows the client to ask
  for it (`allow_hint_override? true`), a second "Use a phone or tablet"
  button is rendered (see `AshAuthentication.Phoenix.WebAuthn.cross_device?/1`).
  It requests the ceremony with `hints: [:hybrid]`, so the browser goes
  straight to the QR code; the request only takes effect when the override
  is allowed. The button's text and class are the
  `AshAuthentication.Phoenix.Components.WebAuthn.Input` overrides
  `cross_device_button_text` and `cross_device_button_class`.

  ## Timeouts

  The ceremony is bounded by the strategy's `timeout` on every side: the
  browser gets it in the request options, the strategy rejects a challenge
  answered after it, and this component stops waiting for the browser when
  it elapses, with no message to the host LiveView. An assertion that
  arrives after that is refused without consulting the strategy.

  On successful authentication, redirects to the `sign_in_with_token` auth path
  (matching the existing auth completion flow used by Password.SignInForm).

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component

  require Logger

  alias AshAuthentication.Info
  alias AshAuthentication.Phoenix.Components.WebAuthn
  alias AshAuthentication.Phoenix.WebAuthn, as: PhoenixWebAuthn
  alias AshAuthentication.Strategy.WebAuthn, as: WebAuthnStrategy

  import AshAuthentication.Phoenix.Components.Helpers,
    only: [auth_path: 6]

  import Slug

  @expired_text "This sign-in request has expired. Please try again."

  @impl Phoenix.LiveComponent
  # The ceremony timer, scheduled with `send_update_after/3` to this very
  # component; nothing else sends it. A ceremony that has already finished
  # (assertion handled, error shown) leaves nothing to time out.
  def update(%{ceremony_timed_out: true}, socket) do
    {:ok, ceremony_timed_out(socket)}
  end

  def update(assigns, socket) do
    # `send_update/2` only passes a subset of assigns, so read everything
    # through the merged socket assigns.
    socket = assign(socket, assigns)
    strategy = socket.assigns.strategy
    subject_name = Info.authentication_subject_name!(strategy.resource)

    socket =
      socket
      |> assign(:subject_name, subject_name)
      |> assign(:subject_name_slug, subject_name |> to_string() |> slugify())
      |> assign(:cross_device?, PhoenixWebAuthn.cross_device?(strategy))
      |> assign_new(:identity_value, fn -> "" end)
      |> assign_new(:error_message, fn -> nil end)
      |> assign_new(:submitting, fn -> false end)
      |> assign_new(:challenge, fn -> nil end)
      |> assign_new(:ceremony_timer, fn -> nil end)
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
    <div
      class={override_for(@overrides, :root_class)}
      id={@id}
      phx-hook="WebAuthnAuthenticationHook"
      phx-target={@myself}
    >
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

        <%= if @cross_device? do %>
          <WebAuthn.Input.cross_device_button
            disabled={@submitting}
            overrides={@overrides}
            gettext_fn={@gettext_fn}
          />
        <% end %>

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

  def handle_event("authenticate", params, socket) do
    strategy = socket.assigns.strategy
    tenant = socket.assigns.current_tenant

    # Sign-in never lists credentials: the challenge is issued before anyone
    # is authenticated, and a submitted identity's credential ids must not
    # be disclosed. The browser offers the discoverable passkeys it holds.
    # The origin the ceremony is accepted from is the strategy's own policy,
    # so nothing about the request is passed along.
    {:ok, challenge} = WebAuthnStrategy.Actions.authentication_challenge(strategy, [], tenant)

    # `hints` names the button that submitted the form ("Use a phone or
    # tablet" asks for `hybrid`); the strategy decides whether it is honoured.
    options =
      strategy
      |> PhoenixWebAuthn.authentication_options(challenge, tenant, [], hints: params["hints"])
      |> PhoenixWebAuthn.target(socket.assigns.id)

    socket =
      socket
      |> cancel_timer()
      |> assign(:challenge, challenge)
      |> assign(:ceremony_timer, start_timer(socket, strategy))
      |> assign(:submitting, true)
      |> assign(:error_message, nil)
      |> Phoenix.LiveView.push_event("authentication-challenge", options)

    {:noreply, socket}
  end

  # The ceremony timed out (or never started) before the browser answered;
  # the strategy would refuse the stale challenge, and must not be handed a
  # missing one.
  def handle_event("authentication-assertion", _params, %{assigns: %{challenge: nil}} = socket) do
    {:noreply,
     assign(socket,
       submitting: false,
       error_message: override_for(socket.assigns.overrides, :expired_text, @expired_text)
     )}
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

    case WebAuthnStrategy.Actions.sign_in(
           strategy,
           sign_in_params,
           challenge: challenge,
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

  def handle_event("authentication-error", params, socket) do
    socket = cancel_timer(socket)

    error_msg =
      case params["name"] do
        "NotAllowedError" -> "The operation was cancelled or not allowed."
        _ -> params["message"] || "Authentication failed. Please try again."
      end

    {:noreply, assign(socket, challenge: nil, submitting: false, error_message: error_msg)}
  end

  # The strategy's `timeout` is the browser's deadline too, so once it has
  # passed nothing more is coming from the hook.
  defp start_timer(socket, strategy) do
    send_update_after(socket.assigns.myself, %{ceremony_timed_out: true}, strategy.timeout)
  end

  defp cancel_timer(socket) do
    if timer_ref = socket.assigns[:ceremony_timer] do
      Process.cancel_timer(timer_ref)
      assign(socket, :ceremony_timer, nil)
    else
      socket
    end
  end

  defp ceremony_timed_out(%{assigns: %{challenge: nil}} = socket), do: socket

  defp ceremony_timed_out(socket) do
    assign(socket,
      challenge: nil,
      ceremony_timer: nil,
      submitting: false,
      error_message:
        override_for(
          socket.assigns.overrides,
          :timeout_text,
          "Authentication timed out. Please try again."
        )
    )
  end
end
