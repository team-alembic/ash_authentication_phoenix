# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.WebAuthn.RegistrationForm do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the heading `h2` element (or `nil` to hide).",
    label_text: "Heading text (or `nil` to hide).",
    description_class: "CSS class for the description `p` element under the heading.",
    description_text:
      "One sentence under the heading explaining what the page asks of the user (or `nil` to hide).",
    form_class: "CSS class for the `form` element.",
    button_text: "Text for the registration button.",
    disable_button_text: "Text shown while the registration ceremony is in progress.",
    slot_class: "CSS class for the `div` surrounding the slot.",
    show_identity_field:
      "Whether to show the identity input. Defaults to `true`; automatically `false` when `require_identity?` is `false` on the strategy.",
    show_key_name_field:
      "Whether to show a passkey label input so users can name their credential (e.g. \"My iPhone\"). Defaults to `false`.",
    show_display_name_field:
      "Whether to show a display name input in passkey-first mode (`require_identity?` is `false`), where it is the only way to label the account inside the passkey. Defaults to `true`; never shown when the strategy requires an identity.",
    show_custom_fields:
      "Whether to automatically render inputs for the fields declared in the strategy's `register_action_accept`. Defaults to `true`.",
    timeout_text: "Error shown when the browser does not answer within the strategy's `timeout`.",
    expired_text:
      "Error shown when an attestation arrives for a ceremony that has already timed out."

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

  ## Heading and description

  The heading (`label_text`) and the one-sentence description under it
  (`description_text`) are what tells a user landing on a passkey page what
  is about to happen; set either to `nil` to drop it.

  ## The secondary button

  When the strategy lets the client choose the kind of authenticator
  (`allow_hint_override? true`), one secondary button is rendered beside
  the main one, pointing away from where the strategy's `hints` lead (see
  `AshAuthentication.Phoenix.WebAuthn.secondary_hint/1`): "Use a phone or
  tablet" requests the ceremony with `hints: [:hybrid]`, so a machine with
  no authenticator of its own can enrol a passkey held on a phone; when the
  strategy already leads with `:hybrid`, "Use a passkey on this device"
  requests `hints: [:client_device]` instead. Without the override the
  request would be ignored, so no button is shown. The texts and the shared
  class are the `AshAuthentication.Phoenix.Components.WebAuthn.Input`
  overrides `cross_device_button_text`, `this_device_button_text` and
  `cross_device_button_class`.

  ## Timeouts

  The ceremony is bounded by the strategy's `timeout` on every side: the
  browser gets it in the creation options, the strategy rejects a challenge
  answered after it, and this component stops waiting for the browser when
  it elapses, with no message to the host LiveView. An attestation that
  arrives after that is refused without consulting the strategy.

  On successful registration, redirects to the `sign_in_with_token` auth path
  (matching the existing auth completion flow used by Password.SignInForm).

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  require Logger
  alias AshAuthentication.{Info, Phoenix.Components.CustomFields, Phoenix.Components.WebAuthn}
  alias AshAuthentication.Phoenix.WebAuthn, as: PhoenixWebAuthn
  alias AshAuthentication.Strategy.WebAuthn, as: WebAuthnStrategy
  alias AshPhoenix.Form

  import AshAuthentication.Phoenix.Components.Helpers,
    only: [auth_path: 6]

  import Slug

  @expired_text "This registration request has expired. Please try again."

  @impl true
  # The ceremony timer, scheduled with `send_update_after/3` to this very
  # component; nothing else sends it.
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
      |> assign(:secondary_hint, PhoenixWebAuthn.secondary_hint(strategy))
      |> assign_new(:identity_value, fn -> "" end)
      |> assign_new(:key_name_value, fn -> "" end)
      |> assign_new(:display_name_value, fn -> "" end)
      |> assign_new(:user_params, fn -> %{} end)
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

    show_display_name =
      !assigns.strategy.require_identity? &&
        override_for(assigns.overrides, :show_display_name_field, true)

    assigns =
      assigns
      |> assign(:show_identity, show_identity)
      |> assign(:show_key_name, show_key_name)
      |> assign(:show_custom_fields, show_custom_fields)
      |> assign(:show_display_name, show_display_name)
      |> assign(
        :disabled,
        assigns.submitting ||
          (assigns.strategy.require_identity? && assigns.identity_value == "")
      )

    ~H"""
    <div
      class={override_for(@overrides, :root_class)}
      id={@id}
      phx-hook="WebAuthnRegistrationHook"
      phx-target={@myself}
    >
      <%= if label_text = override_for(@overrides, :label_text) do %>
        <h2 class={override_for(@overrides, :label_class)}>{_gettext(label_text)}</h2>
      <% end %>
      <%= if description_text = override_for(@overrides, :description_text) do %>
        <p class={override_for(@overrides, :description_class)}>{_gettext(description_text)}</p>
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

        <%= if @show_display_name do %>
          <WebAuthn.Input.display_name_field
            id={@id <> "-display-name"}
            value={@display_name_value}
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
          disabled={@disabled}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />

        <%= if @secondary_hint do %>
          <WebAuthn.Input.hint_button
            hint={@secondary_hint}
            disabled={@disabled}
            overrides={@overrides}
            gettext_fn={@gettext_fn}
          />
        <% end %>

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
    display_name_value = Map.get(params, "display_name", socket.assigns.display_name_value)

    form = Form.validate(socket.assigns.form, user_params, errors: false)

    {:noreply,
     assign(socket,
       form: form,
       user_params: user_params,
       identity_value: identity_value,
       key_name_value: key_name_value,
       display_name_value: display_name_value
     )}
  end

  def handle_event("register", params, socket) do
    user_params = Map.get(params, to_string(socket.assigns.subject_name), %{})
    key_name = Map.get(params, "key_name", socket.assigns.key_name_value)
    display_name = Map.get(params, "display_name", socket.assigns.display_name_value)

    identity_value =
      Map.get(
        user_params,
        to_string(socket.assigns.strategy.identity_field),
        socket.assigns.identity_value
      )

    form = Form.validate(socket.assigns.form, user_params)

    socket =
      assign(socket,
        form: form,
        user_params: user_params,
        identity_value: identity_value,
        key_name_value: key_name,
        display_name_value: display_name
      )

    # The register action also requires the credential produced by the
    # ceremony, so `form.valid?` can never be true here — gate the ceremony
    # on the user-facing fields only. Full validation happens server-side in
    # `WebAuthn.Actions.register/3` once the attestation comes back.
    case user_facing_errors(form, socket.assigns) do
      [] ->
        # `hints` names the button that submitted the form (the secondary one
        # asks for `hybrid` or `client-device`); the strategy decides whether
        # it is honoured.
        start_registration_ceremony(socket, params["hints"])

      _errors ->
        {:noreply, socket}
    end
  end

  # The ceremony timed out (or never started) before the browser answered;
  # the strategy would refuse the stale challenge, and must not be handed a
  # missing one.
  def handle_event("registration-attestation", _params, %{assigns: %{challenge: nil}} = socket) do
    {:noreply,
     assign(socket,
       submitting: false,
       error_message: override_for(socket.assigns.overrides, :expired_text, @expired_text)
     )}
  end

  def handle_event("registration-attestation", params, socket) do
    socket = cancel_timer(socket)
    strategy = socket.assigns.strategy
    challenge = socket.assigns.challenge

    # A blank label is passed as `nil` so the credential resource's
    # attribute default applies. `transports` and `cred_props` are
    # client-reported hints the action sanitizes and stores.
    label =
      case socket.assigns.key_name_value do
        "" -> nil
        key_name -> key_name
      end

    register_params =
      socket.assigns.user_params
      |> Map.put(
        to_string(strategy.identity_field),
        socket.assigns.identity_value
      )
      |> Map.merge(%{
        "attestation_object" => params["attestation_object"],
        "client_data_json" => params["client_data_json"],
        "raw_id" => params["raw_id"],
        "label" => label,
        "transports" => params["transports"],
        "cred_props" => params["cred_props"]
      })

    case WebAuthnStrategy.Actions.register(
           strategy,
           register_params,
           challenge: challenge,
           tenant: socket.assigns.current_tenant,
           user_handle: socket.assigns[:user_handle]
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

  def handle_event("registration-error", params, socket) do
    socket = cancel_timer(socket)

    error_msg =
      case params["name"] do
        "NotAllowedError" -> "The operation was cancelled or not allowed."
        "InvalidStateError" -> "This authenticator is already registered."
        _ -> params["message"] || "Registration failed. Please try again."
      end

    {:noreply, assign(socket, challenge: nil, submitting: false, error_message: error_msg)}
  end

  defp start_registration_ceremony(socket, requested_hints) do
    strategy = socket.assigns.strategy
    tenant = socket.assigns.current_tenant

    # The origin the ceremony is accepted from is the strategy's own policy
    # (its `origin` allowlist, or any `https` origin on its `rp_id`), so the
    # request's host is not consulted.
    {:ok, challenge} = WebAuthnStrategy.Actions.registration_challenge(strategy, tenant)

    # The server mints the user handle (persisted on the credential after
    # the ceremony); the client must use it verbatim. In passkey-first mode
    # the passkey name becomes the descriptor's `name` (what password
    # managers show as the saved key's username) and `display_name` its
    # friendly label — both must be set before the ceremony, as most
    # password managers don't allow renaming afterwards.
    {user_descriptor, user_handle} =
      PhoenixWebAuthn.new_user_descriptor(
        socket.assigns.identity_value,
        socket.assigns.display_name_value,
        socket.assigns.key_name_value
      )

    options =
      strategy
      |> PhoenixWebAuthn.registration_options(challenge, tenant, user_descriptor, [],
        hints: requested_hints
      )
      |> PhoenixWebAuthn.target(socket.assigns.id)

    socket =
      socket
      |> cancel_timer()
      |> assign(:challenge, challenge)
      |> assign(:user_handle, user_handle)
      |> assign(:ceremony_timer, start_timer(socket, strategy))
      |> assign(:submitting, true)
      |> assign(:error_message, nil)
      |> Phoenix.LiveView.push_event("registration-challenge", options)

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
          "Registration timed out. Please try again."
        )
    )
  end
end
