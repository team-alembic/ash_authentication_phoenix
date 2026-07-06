# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.WebAuthn.RegistrationForm do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the heading `h2` element (or `nil` to hide).",
    label_text: "Heading text (or `nil` to hide).",
    form_class: "CSS class for the `form` element.",
    button_text: "Text for the registration button.",
    disable_button_text: "Text shown while the registration ceremony is in progress.",
    slot_class: "CSS class for the `div` surrounding the slot.",
    show_identity_field:
      "Whether to show the identity input. Defaults to `true`; automatically `false` when `require_identity?` is `false` on the strategy.",
    show_key_name_field:
      "Whether to show a passkey label input so users can name their credential (e.g. \"My iPhone\"). Defaults to `false`.",
    show_custom_fields:
      "Whether to automatically render inputs for the fields declared in the strategy's `register_action_accept`. Defaults to `true`."

  @moduledoc """
  Registration form for WebAuthn.

  Renders an identity input and a "Register with Passkey" button.
  On click, generates a challenge, pushes it to the JS hook,
  and handles the attestation response.

  The form is backed by an `AshPhoenix.Form` for the strategy's register
  action, so user-facing inputs are validated by the action's regular
  validation rules (`allow_nil?`, constraints, validations) as the user
  types, and the WebAuthn ceremony only starts once those inputs are valid.

  ## Custom fields

  Any writable attributes listed in the strategy's `register_action_accept`
  DSL option are automatically rendered below the identity input, with input
  types derived from the attribute definitions (see
  `AshAuthentication.Phoenix.Components.CustomFields`). Set the
  `show_custom_fields` override to `false` to render them yourself via the
  slot instead.

  On successful registration, redirects to the `sign_in_with_token` auth path
  (matching the existing auth completion flow used by Password.SignInForm).

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  require Logger
  alias AshAuthentication.{Info, Phoenix.Components.CustomFields, Phoenix.Components.WebAuthn}
  alias AshPhoenix.Form

  import AshAuthentication.Phoenix.Components.Helpers,
    only: [auth_path: 6]

  import Slug

  @impl true
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
      |> assign_new(:key_name_value, fn -> "" end)
      |> assign_new(:user_params, fn -> %{} end)
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
      |> assign_new(:custom_fields, fn ->
        AshAuthentication.Strategy.CustomFields.register_fields(strategy)
      end)

    socket = assign_new(socket, :form, fn -> build_form(socket.assigns) end)

    {:ok, socket}
  end

  defp build_form(assigns) do
    strategy = assigns.strategy
    domain = Info.authentication_domain!(strategy.resource)

    context =
      assigns.context
      |> Kernel.||(%{})
      |> Map.put(:token_type, :sign_in)
      |> Map.put(:strategy, strategy)
      |> Map.update(
        :private,
        %{ash_authentication?: true},
        &Map.put(&1, :ash_authentication?, true)
      )

    strategy.resource
    |> Form.for_action(strategy.register_action_name,
      domain: domain,
      as: assigns.subject_name |> to_string(),
      transform_errors: _transform_errors(),
      tenant: assigns.current_tenant,
      context: context,
      id:
        "#{assigns.subject_name}-#{strategy.name}-#{strategy.register_action_name}"
        |> slugify()
    )
  end

  @impl true
  def render(assigns) do
    show_identity =
      assigns.strategy.require_identity? &&
        override_for(assigns.overrides, :show_identity_field, true)

    show_key_name = override_for(assigns.overrides, :show_key_name_field, true)
    show_custom_fields = override_for(assigns.overrides, :show_custom_fields, true)

    assigns =
      assigns
      |> assign(:show_identity, show_identity)
      |> assign(:show_key_name, show_key_name)
      |> assign(:show_custom_fields, show_custom_fields)

    ~H"""
    <div class={override_for(@overrides, :root_class)} id={@id} phx-hook="WebAuthnRegistrationHook">
      <%= if label_text = override_for(@overrides, :label_text) do %>
        <h2 class={override_for(@overrides, :label_class)}>{_gettext(label_text)}</h2>
      <% end %>
      <.form
        :let={form}
        for={@form}
        id={"#{@id}-form"}
        phx-change="validate"
        phx-submit="register"
        phx-target={@myself}
        class={override_for(@overrides, :form_class)}
      >
        <%= if @show_identity do %>
          <WebAuthn.Input.identity_field
            id={@id <> "-identity"}
            form={form}
            identity_field={@strategy.identity_field}
            overrides={@overrides}
            gettext_fn={@gettext_fn}
          />
        <% end %>

        <%= if @show_custom_fields do %>
          <CustomFields.field
            :for={{attribute, secret?} <- @custom_fields}
            form={form}
            attribute={attribute}
            secret?={secret?}
            overrides={@overrides}
            gettext_fn={@gettext_fn}
          />
        <% end %>

        <%= if @show_key_name do %>
          <WebAuthn.Input.key_name_field
            id={@id <> "-key-name"}
            value={@key_name_value}
            overrides={@overrides}
            gettext_fn={@gettext_fn}
          />
        <% end %>

        <WebAuthn.Input.register_button
          disabled={@submitting || (@strategy.require_identity? && @identity_value == "")}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />

        <WebAuthn.Input.error
          message={@error_message}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />
      </.form>

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

  @impl true
  def handle_event("validate", params, socket) do
    user_params = Map.get(params, to_string(socket.assigns.subject_name), %{})

    identity_value =
      Map.get(user_params, to_string(socket.assigns.strategy.identity_field), "")

    key_name_value = Map.get(params, "key_name", socket.assigns.key_name_value)

    form = Form.validate(socket.assigns.form, user_params, errors: false)

    {:noreply,
     assign(socket,
       form: form,
       user_params: user_params,
       identity_value: identity_value,
       key_name_value: key_name_value
     )}
  end

  alias AshAuthentication.Phoenix.WebAuthn, as: PhoenixWebAuthn
  alias AshAuthentication.Strategy.WebAuthn, as: WebAuthnStrategy

  @registration_timeout_ms 60_000

  def handle_event("register", params, socket) do
    user_params = Map.get(params, to_string(socket.assigns.subject_name), %{})
    key_name = Map.get(params, "key_name", socket.assigns.key_name_value)

    form = Form.validate(socket.assigns.form, user_params)
    socket = assign(socket, form: form, user_params: user_params, key_name_value: key_name)

    # The register action also requires the credential produced by the
    # ceremony, so `form.valid?` can never be true here — gate the ceremony
    # on the user-facing fields only. Full validation happens server-side in
    # `WebAuthn.Actions.register/3` once the attestation comes back.
    case user_facing_errors(form, socket.assigns) do
      [] ->
        start_registration_ceremony(socket)

      _errors ->
        {:noreply, socket}
    end
  end

  def handle_event("registration-attestation", params, socket) do
    socket = cancel_timer(socket)
    strategy = socket.assigns.strategy
    challenge = socket.assigns.challenge

    register_params =
      socket.assigns.user_params
      |> Map.put(
        to_string(strategy.identity_field),
        socket.assigns.identity_value
      )
      |> Map.put(to_string(strategy.label_field), socket.assigns.key_name_value)
      |> Map.merge(%{
        "attestation_object" => params["attestation_object"],
        "client_data_json" => params["client_data_json"],
        "raw_id" => params["raw_id"]
      })

    origin = PhoenixWebAuthn.origin_from_socket(socket)

    case WebAuthnStrategy.Actions.register(
           strategy,
           register_params,
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
        Logger.error("WebAuthn registration failed: #{inspect(error)}")

        {:noreply,
         assign(socket,
           challenge: nil,
           submitting: false,
           error_message: "Registration failed. Please try again."
         )}
    end
  end

  def handle_event("registration-error", %{"name" => name, "message" => message}, socket) do
    socket = cancel_timer(socket)

    error_msg =
      case name do
        "NotAllowedError" -> "The operation was cancelled or not allowed."
        "InvalidStateError" -> "This authenticator is already registered."
        _ -> message
      end

    {:noreply, assign(socket, challenge: nil, submitting: false, error_message: error_msg)}
  end

  defp start_registration_ceremony(socket) do
    strategy = socket.assigns.strategy
    tenant = socket.assigns.current_tenant
    origin = PhoenixWebAuthn.origin_from_socket(socket)

    {:ok, challenge} =
      WebAuthnStrategy.Actions.registration_challenge(strategy, tenant, origin: origin)

    rp_id = WebAuthnStrategy.Helpers.resolve_rp_id(strategy, tenant)
    rp_name = WebAuthnStrategy.Helpers.resolve_rp_name(strategy, tenant)

    user_id = Base.url_encode64(:crypto.strong_rand_bytes(64), padding: false)

    identity = socket.assigns.identity_value
    key_name = socket.assigns.key_name_value

    # user_name must uniquely identify the account; display_name is human-readable.
    # When a passkey label is set, use it as the display name.
    user_name = if identity != "", do: identity, else: key_name
    user_display_name = if key_name != "", do: key_name, else: identity

    timer_ref = Process.send_after(self(), :registration_timeout, @registration_timeout_ms)

    socket =
      socket
      |> assign(:challenge, challenge)
      |> assign(:registration_timer_ref, timer_ref)
      |> assign(:submitting, true)
      |> Phoenix.LiveView.push_event("registration-challenge", %{
        challenge: Base.url_encode64(challenge.bytes, padding: false),
        rp_id: rp_id,
        rp_name: rp_name,
        user_id: user_id,
        user_name: user_name,
        user_display_name: user_display_name,
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

  defp user_facing_errors(form, assigns) do
    strategy = assigns.strategy

    custom_field_names =
      Enum.map(assigns.custom_fields, fn {attribute, _secret?} -> attribute.name end)

    user_fields =
      if strategy.require_identity?,
        do: [strategy.identity_field | custom_field_names],
        else: custom_field_names

    form
    |> Form.errors()
    |> Keyword.take(user_fields)
  end

  defp cancel_timer(socket) do
    if timer_ref = socket.assigns[:registration_timer_ref] do
      Process.cancel_timer(timer_ref)
      assign(socket, :registration_timer_ref, nil)
    else
      socket
    end
  end
end
