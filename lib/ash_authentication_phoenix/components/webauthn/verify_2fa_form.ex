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
    error_class: "CSS class for error messages.",
    error_unauthenticated_text:
      "Text shown when the user is neither authenticated nor presenting a valid token.",
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

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component

  alias AshAuthentication.Info
  alias AshAuthentication.Phoenix.WebAuthn, as: PhoenixWebAuthnLib
  alias AshAuthentication.Strategy.WebAuthn
  alias AshAuthentication.Strategy.WebAuthn.Helpers, as: WebAuthnHelpers
  alias Phoenix.LiveView.{Rendered, Socket}

  import AshAuthentication.Phoenix.Components.Helpers,
    only: [auth_path: 6]

  import Slug

  @impl true
  @spec update(map, Socket.t()) :: {:ok, Socket.t()}
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

    socket =
      if socket.assigns.strategy && socket.assigns.resource do
        subject_name = Info.authentication_subject_name!(socket.assigns.resource)
        assign(socket, :subject_name_slug, subject_name |> to_string() |> slugify())
      else
        assign(socket, :subject_name_slug, nil)
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
          </form>

          <%= if @subject_name_slug && @strategy && @auth_routes_prefix do %>
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
  def handle_event("start-verify", _params, socket) do
    strategy = socket.assigns.strategy
    actor = resolve_actor(socket)
    tenant = socket.assigns.current_tenant
    origin = PhoenixWebAuthnLib.origin_from_socket(socket)

    if actor do
      {:ok, allow_credentials} = load_allow_credentials(strategy, actor, tenant)

      {:ok, challenge} =
        WebAuthn.Actions.authentication_challenge(strategy, allow_credentials, tenant,
          origin: origin
        )

      rp_id = WebAuthnHelpers.resolve_rp_id(strategy, tenant)

      socket =
        socket
        |> assign(:challenge, challenge)
        |> assign(:submitting, true)
        |> assign(:error_message, nil)
        |> Phoenix.LiveView.push_event("authentication-challenge", %{
          challenge: Base.url_encode64(challenge.bytes, padding: false),
          rp_id: rp_id,
          timeout: strategy.timeout,
          user_verification: strategy.user_verification,
          allow_credentials:
            Enum.map(allow_credentials, fn {cred_id, _cose_key} ->
              %{id: Base.url_encode64(cred_id, padding: false), type: "public-key"}
            end)
        })

      {:noreply, socket}
    else
      {:noreply,
       assign(socket,
         submitting: false,
         error_message: "Unable to identify the user for this verification."
       )}
    end
  end

  def handle_event("authentication-assertion", params, socket) do
    strategy = socket.assigns.strategy
    challenge = socket.assigns.challenge
    actor = resolve_actor(socket)

    verify_params = %{
      "raw_id" => params["raw_id"],
      "authenticator_data" => params["authenticator_data"],
      "signature" => params["signature"],
      "client_data_json" => params["client_data_json"]
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

  def handle_event("authentication-error", %{"name" => name, "message" => message}, socket) do
    error_msg =
      case name do
        "NotAllowedError" -> "The operation was cancelled or not allowed."
        "InvalidStateError" -> "This authenticator is not registered."
        _ -> message
      end

    {:noreply,
     assign(socket,
       challenge: nil,
       submitting: false,
       error_message: error_msg
     )}
  end

  defp resolve_actor(%{assigns: %{current_user: %_{} = user}}), do: user

  defp resolve_actor(%{assigns: %{mode: :token, token: token, resource: resource}})
       when is_binary(token) and not is_nil(resource) do
    case AshAuthentication.Jwt.verify(token, resource) do
      {:ok, %{"sub" => subject}, _} ->
        case AshAuthentication.subject_to_user(subject, resource, authorize?: false) do
          {:ok, user} -> user
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp resolve_actor(_), do: nil

  defp load_allow_credentials(strategy, actor, tenant) do
    ash_opts = [authorize?: false]
    ash_opts = if tenant, do: Keyword.put(ash_opts, :tenant, tenant), else: ash_opts

    case Ash.load(actor, [strategy.credentials_relationship_name], ash_opts) do
      {:ok, loaded} ->
        creds =
          loaded
          |> Map.get(strategy.credentials_relationship_name, [])
          |> Enum.map(fn cred ->
            {Map.get(cred, strategy.credential_id_field),
             Map.get(cred, strategy.public_key_field)}
          end)

        {:ok, creds}

      _ ->
        {:ok, []}
    end
  end
end
