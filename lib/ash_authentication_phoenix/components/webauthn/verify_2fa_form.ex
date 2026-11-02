# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
defmodule AshAuthentication.Phoenix.Components.WebAuthn.Verify2faForm do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the heading.",
    label_text: "Heading text.",
    instructions_class: "CSS class for the instructions paragraph.",
    instructions_text: "Instructions shown above the verify button.",
    form_class: "CSS class for the visible form wrapping the verify button.",
    submit_class: "CSS class for the submit button.",
    submit_text: "Text shown on the verify button.",
    submit_disabled_text: "Text shown on the verify button while the ceremony is in flight.",
    cross_device_button_text:
      "Text for the \"Use a phone or tablet\" button, shown when the strategy offers the `:hybrid` hint or allows the client to request it.",
    cross_device_button_class: "CSS class for the \"Use a phone or tablet\" button.",
    error_class: "CSS class for error messages.",
    error_unauthenticated_text:
      "Text shown when the user is neither authenticated nor presenting a valid token.",
    timeout_text: "Error shown when the browser does not answer within the strategy's `timeout`.",
    expired_text:
      "Error shown when an assertion arrives for a ceremony that has already timed out.",
    sign_in_link_class: "CSS class for the sign-in fallback link.",
    sign_in_link_path: "Path of the sign-in page.",
    sign_in_link_text: "Text for the sign-in fallback link."

  @moduledoc """
  Drives the WebAuthn second-factor ceremony.

  Two modes:

  * `:token` — primary sign-in just completed; `@token` is the short-lived
    JWT issued by the primary strategy. After a successful WebAuthn
    assertion the token is exchanged at the strategy's `sign_in_with_token`
    endpoint for a session that carries the `:webauthn_verified_at` metadata.
  * `:step_up` — already-authenticated user re-asserting. No token; the
    component issues its own short-lived token after the ceremony so the
    same exchange can produce a refreshed session.

  Reuses the existing `WebAuthnAuthenticationHook` JS hook because the
  challenge / assertion shape is identical to a primary-mode sign-in
  ceremony — the only difference is server-side scoping to the actor's
  credentials.

  ## Cross-device verification

  When the strategy offers the `:hybrid` hint, or allows the client to ask
  for it (`allow_hint_override? true`), a second "Use a phone or tablet"
  button is rendered (see `AshAuthentication.Phoenix.WebAuthn.cross_device?/1`).
  It requests the ceremony with `hints: [:hybrid]`, which only takes effect
  when the override is allowed.

  ## Timeouts

  The ceremony is bounded by the strategy's `timeout`: the browser gets it
  in the request options, the strategy rejects a challenge answered after
  it, and this component stops waiting for the browser when it elapses,
  with no message to the host LiveView.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component

  alias AshAuthentication.Info
  alias AshAuthentication.Phoenix.WebAuthn, as: PhoenixWebAuthnLib
  alias AshAuthentication.Strategy.WebAuthn
  alias Phoenix.LiveView.{Rendered, Socket}

  import AshAuthentication.Phoenix.Components.Helpers,
    only: [auth_path: 6]

  import Slug

  @expired_text "This verification request has expired. Please try again."

  @impl true
  @spec update(map, Socket.t()) :: {:ok, Socket.t()}
  # The ceremony timer, scheduled with `send_update_after/3` to this very
  # component; nothing else sends it.
  def update(%{ceremony_timed_out: true}, socket) do
    {:ok, ceremony_timed_out(socket)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:context, fn -> %{} end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)
      |> assign_new(:token, fn -> nil end)
      |> assign_new(:mode, fn -> :error end)
      |> assign_new(:current_user, fn -> nil end)
      |> assign_new(:error_message, fn -> nil end)
      |> assign_new(:submitting, fn -> false end)
      |> assign_new(:trigger_action, fn -> false end)
      |> assign_new(:sign_in_token, fn -> nil end)
      |> assign_new(:challenge, fn -> nil end)
      |> assign_new(:ceremony_timer, fn -> nil end)

    socket =
      if socket.assigns.strategy && socket.assigns.resource do
        subject_name = Info.authentication_subject_name!(socket.assigns.resource)

        socket
        |> assign(:subject_name_slug, subject_name |> to_string() |> slugify())
        |> assign(:cross_device?, PhoenixWebAuthnLib.cross_device?(socket.assigns.strategy))
      else
        socket
        |> assign(:subject_name_slug, nil)
        |> assign(:cross_device?, false)
      end

    {:ok, socket}
  end

  @impl true
  @spec render(Socket.assigns()) :: Rendered.t()
  def render(assigns) do
    ~H"""
    <div
      class={override_for(@overrides, :root_class)}
      id={@id}
      phx-hook="WebAuthnAuthenticationHook"
      phx-target={@myself}
    >
      <h2 class={override_for(@overrides, :label_class)}>
        {_gettext(override_for(@overrides, :label_text))}
      </h2>

      <p class={override_for(@overrides, :instructions_class)}>
        {_gettext(override_for(@overrides, :instructions_text))}
      </p>

      <%= if @error_message do %>
        <div class={override_for(@overrides, :error_class)}>
          {_gettext(@error_message)}
        </div>
      <% end %>

      <%= case @mode do %>
        <% :error -> %>
          <p class={override_for(@overrides, :error_class)}>
            {_gettext(override_for(@overrides, :error_unauthenticated_text))}
          </p>
          <a
            href={override_for(@overrides, :sign_in_link_path, "/sign-in")}
            class={override_for(@overrides, :sign_in_link_class)}
          >
            {_gettext(override_for(@overrides, :sign_in_link_text, "Sign in"))}
          </a>
        <% _ -> %>
          <form
            id={"#{@id}-form"}
            phx-submit="start-verify"
            phx-target={@myself}
            class={override_for(@overrides, :form_class)}
          >
            <button
              type="submit"
              disabled={@submitting}
              class={override_for(@overrides, :submit_class)}
            >
              <%= if @submitting do %>
                {_gettext(override_for(@overrides, :submit_disabled_text))}
              <% else %>
                {_gettext(override_for(@overrides, :submit_text))}
              <% end %>
            </button>

            <%= if @cross_device? do %>
              <button
                type="submit"
                name="hints"
                value="hybrid"
                disabled={@submitting}
                class={override_for(@overrides, :cross_device_button_class)}
              >
                {_gettext(
                  override_for(@overrides, :cross_device_button_text, "Use a phone or tablet")
                )}
              </button>
            <% end %>
          </form>

          <%= if @subject_name_slug && @strategy do %>
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
          <% end %>
      <% end %>
    </div>
    """
  end

  @impl true
  @spec handle_event(String.t(), %{required(String.t()) => any()}, Socket.t()) ::
          {:noreply, Socket.t()}
  def handle_event("start-verify", params, socket) do
    strategy = socket.assigns.strategy
    actor = resolve_actor(socket)
    tenant = socket.assigns.current_tenant

    if actor do
      credentials = load_credentials(strategy, actor, tenant)

      # Unlike sign-in, the caller here is already authenticated, so the
      # actor's own credentials can be listed — which is also what lets a
      # non-discoverable security key answer. The field names come from the
      # credential resource, which may rename any of them.
      credential_id_field = WebAuthn.credential_id_field(strategy)
      public_key_field = WebAuthn.public_key_field(strategy)

      allow_credentials =
        Enum.map(credentials, fn cred ->
          {Map.get(cred, credential_id_field), Map.get(cred, public_key_field)}
        end)

      {:ok, challenge} =
        WebAuthn.Actions.authentication_challenge(strategy, allow_credentials, tenant)

      # `hints` names the button that submitted the form ("Use a phone or
      # tablet" asks for `hybrid`); the strategy decides whether it is honoured.
      options =
        strategy
        |> PhoenixWebAuthnLib.authentication_options(challenge, tenant, credentials,
          hints: params["hints"]
        )
        |> PhoenixWebAuthnLib.target(socket.assigns.id)

      socket =
        socket
        |> cancel_timer()
        |> assign(:challenge, challenge)
        |> assign(:ceremony_timer, start_timer(socket, strategy))
        |> assign(:submitting, true)
        |> assign(:error_message, nil)
        |> Phoenix.LiveView.push_event("authentication-challenge", options)

      {:noreply, socket}
    else
      {:noreply,
       assign(socket,
         submitting: false,
         error_message: "Unable to identify the user for this verification."
       )}
    end
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

    # The actor is resolved again rather than remembered from the challenge:
    # a token may have expired, or the session ended, while the browser was
    # prompting. Without one there is nobody to verify for.
    case resolve_actor(socket) do
      nil ->
        {:noreply,
         assign(socket,
           challenge: nil,
           submitting: false,
           error_message: "Unable to identify the user for this verification."
         )}

      actor ->
        verify(socket, strategy, actor, challenge, params)
    end
  end

  def handle_event("authentication-error", params, socket) do
    socket = cancel_timer(socket)

    error_msg =
      case params["name"] do
        "NotAllowedError" -> "The operation was cancelled or not allowed."
        "InvalidStateError" -> "This authenticator is not registered."
        _ -> params["message"] || "Verification failed. Please try again."
      end

    {:noreply,
     assign(socket,
       challenge: nil,
       submitting: false,
       error_message: error_msg
     )}
  end

  defp verify(socket, strategy, actor, challenge, params) do
    # `user_handle` is the assertion's `response.userHandle`. The strategy
    # checks it against the credential's stored handle whenever both are
    # known (WebAuthn §7.2 step 6), on verify as much as on sign-in.
    verify_params = %{
      "raw_id" => params["raw_id"],
      "authenticator_data" => params["authenticator_data"],
      "signature" => params["signature"],
      "client_data_json" => params["client_data_json"],
      "user_handle" => params["user_handle"]
    }

    case WebAuthn.Actions.verify(strategy, verify_params,
           actor: actor,
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

      {:error, _error} ->
        {:noreply,
         assign(socket,
           challenge: nil,
           submitting: false,
           error_message: "Verification failed. Please try again."
         )}
    end
  end

  defp resolve_actor(%{assigns: %{current_user: %_{} = user}}), do: user

  defp resolve_actor(%{
         assigns: %{mode: :token, token: token, resource: resource, current_tenant: tenant}
       })
       when is_binary(token) and not is_nil(resource) do
    case AshAuthentication.Jwt.verify(token, resource) do
      {:ok, %{"sub" => subject}, _} ->
        # The user is looked up in the tenant the page is served for; a
        # multi-tenant user resource finds nothing otherwise.
        case AshAuthentication.subject_to_user(subject, resource,
               authorize?: false,
               tenant: tenant
             ) do
          {:ok, user} -> user
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp resolve_actor(_), do: nil

  defp load_credentials(strategy, actor, tenant) do
    ash_opts = [authorize?: false]
    ash_opts = if tenant, do: Keyword.put(ash_opts, :tenant, tenant), else: ash_opts

    case Ash.load(actor, [strategy.credentials_relationship_name], ash_opts) do
      {:ok, loaded} -> Map.get(loaded, strategy.credentials_relationship_name, [])
      _ -> []
    end
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
          "Verification timed out. Please try again."
        )
    )
  end
end
