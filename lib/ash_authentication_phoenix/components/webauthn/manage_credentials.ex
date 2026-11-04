# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.WebAuthn.ManageCredentials do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the management panel root `div`.",
    heading_text: "Heading text for the panel.",
    heading_class: "CSS class for the heading.",
    credential_list_class: "CSS class for the credential list.",
    credential_item_class: "CSS class for each credential row.",
    add_button_text: "Text for the add credential button.",
    add_button_class: "CSS class for the add button.",
    delete_button_text: "Text for the delete button.",
    delete_button_class: "CSS class for the delete button.",
    rename_button_text: "Text for the rename button.",
    rename_button_class: "CSS class for the rename button.",
    save_button_text: "Text for the save label button.",
    cancel_button_text: "Text for the cancel rename button.",
    empty_state_text: "Text shown when no credentials exist.",
    last_credential_warning: "Warning when trying to delete the last credential.",
    label_input_class: "CSS class for the label input.",
    timestamp_class: "CSS class for timestamp text.",
    synced_badge_text:
      "Badge text shown for synced passkeys (credentials whose backup state flag is set).",
    synced_badge_class: "CSS class for the synced passkey badge.",
    continue_button_text:
      "Text for the continue button shown after at least one credential is registered.",
    continue_button_class: "CSS class for the continue button.",
    add_form_class: "CSS class for the `form` wrapping the passkey name input and add button.",
    show_key_name_field:
      "Whether to show a passkey name input before adding a new credential, so the name is set before the browser ceremony stores it in the user's password manager. Defaults to `true`.",
    reauthentication_path:
      "Where to send the user when adding a passkey needs a more recent authentication than their session carries (the strategy's `add_credential_max_authentication_age`). Defaults to the second-factor verify page (`/webauthn-verify`) when the user already has a passkey and the strategy verifies, otherwise to the sign-in page (`/sign-in`).",
    reauthentication_text:
      "Flash message shown when the user is sent to re-authenticate before adding a passkey.",
    timeout_text:
      "Error shown when the browser does not answer the add-passkey ceremony within the strategy's `timeout`.",
    expired_text:
      "Error shown when an attestation arrives for an add-passkey ceremony that has already timed out."

  @moduledoc """
  Credential management panel for authenticated users.

  Displays all registered security keys/passkeys with options to rename,
  delete, and add new credentials.

  Prevents deletion of the last credential.

  All credential operations go through `AshAuthentication.Strategy.WebAuthn.Actions`
  — the Ash resource layer is never bypassed. Credential fields are read
  through the strategy's accessors, so a credential resource that renames
  any of them (or uses a primary key other than `:id`) works unchanged.

  ## Adding a passkey

  A passkey is a lasting way into the account, so the strategy decides who
  may add one:

    * with `add_credential_enabled? false` the add affordance is not
      rendered at all;
    * with `add_credential_max_authentication_age` set, the user must have
      authenticated within that window. The component checks this *before*
      starting the browser ceremony and, when the session is too old, sends
      the user to re-authenticate (see the `reauthentication_path` override)
      rather than letting them touch an authenticator for nothing. The
      strategy enforces the same rule when the credential is stored, in case
      the window lapses mid-ceremony; that refusal takes the same route.

  What counts as authenticating is the actor's metadata — the session
  token's issue time, or a second-factor verification — which
  `AshAuthentication.Phoenix.LiveSession` restores from the session. An
  application that knows better (its own re-authentication step, say) can
  pass `authenticated_at` instead.

  When the strategy offers the `:hybrid` hint, or allows the client to ask
  for it (`allow_hint_override? true`), the add form also renders a "Use a
  phone or tablet" button (see
  `AshAuthentication.Phoenix.WebAuthn.cross_device?/1`) for enrolling a
  passkey held on a phone. The ceremony is bounded by the strategy's
  `timeout`; this component stops waiting for the browser when it elapses.

  ## Props

    * `strategy` - The WebAuthn strategy configuration. Required.
    * `current_user` - The authenticated user. Required.
    * `authenticated_at` - When the user last authenticated, as a
      `DateTime`, if the application knows it better than the user's
      metadata does. Optional.
    * `continue_path` - When set, a "Continue" link to this path is shown
      once at least one credential is registered. Optional.
    * `overrides` - A list of override modules.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias Ash.Resource.Info, as: ResourceInfo
  alias AshAuthentication.Errors.AuthenticationFailed
  alias AshAuthentication.Phoenix.Components.WebAuthn.Input
  alias AshAuthentication.Phoenix.WebAuthn, as: PhoenixWebAuthn
  alias AshAuthentication.Strategy.WebAuthn
  alias AshAuthentication.Strategy.WebAuthn.RecentAuthentication

  @default_verify_path "/webauthn-verify"
  @default_sign_in_path "/sign-in"
  @expired_text "This request has expired. Please try adding the passkey again."

  @impl Phoenix.LiveComponent
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
      |> assign_new(:editing_id, fn -> nil end)
      |> assign_new(:editing_label, fn -> "" end)
      |> assign_new(:error_message, fn -> nil end)
      |> assign_new(:adding, fn -> false end)
      |> assign_new(:add_challenge, fn -> nil end)
      |> assign_new(:ceremony_timer, fn -> nil end)
      |> assign_new(:key_name_value, fn -> "" end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:continue_path, fn -> nil end)
      |> assign_new(:authenticated_at, fn -> nil end)

    # `send_update/2` may carry only a subset of assigns, so the user is
    # looked for on the merged socket, not on this update alone.
    unless socket.assigns[:current_user] do
      raise ArgumentError, "ManageCredentials requires a :current_user assign"
    end

    # The credential resource may rename any of its fields, and its primary
    # key need not be `:id`. The accessors walk its DSL, so resolve them once
    # per update rather than per credential row.
    socket =
      socket
      |> assign(:fields, credential_fields(socket.assigns.strategy))
      |> assign(:cross_device?, PhoenixWebAuthn.cross_device?(socket.assigns.strategy))
      |> assign_new(:credentials, fn -> fetch_credentials(socket) end)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)} id={@id}>
      <h2 class={override_for(@overrides, :heading_class)}>
        {_gettext(override_for(@overrides, :heading_text, "Your Security Keys"))}
      </h2>

      <%= if @error_message do %>
        <div class="text-red-600 text-sm mb-4">{_gettext(@error_message)}</div>
      <% end %>

      <%= if @credentials == [] do %>
        <p>{_gettext(override_for(@overrides, :empty_state_text, "No security keys registered."))}</p>
      <% else %>
        <ul class={override_for(@overrides, :credential_list_class)}>
          <%= for credential <- @credentials, credential_id = credential_id(credential, @fields) do %>
            <li class={override_for(@overrides, :credential_item_class)}>
              <%= if @editing_id == credential_id do %>
                <form
                  id={"credential-#{credential_id}-form"}
                  phx-submit="save-label"
                  phx-target={@myself}
                >
                  <input type="hidden" name="credential_id" value={credential_id} />
                  <input
                    type="text"
                    name="label"
                    value={@editing_label}
                    class={override_for(@overrides, :label_input_class)}
                    autofocus
                  />
                  <button type="submit">
                    {_gettext(override_for(@overrides, :save_button_text, "Save"))}
                  </button>
                  <button type="button" phx-click="cancel-edit" phx-target={@myself}>
                    {_gettext(override_for(@overrides, :cancel_button_text, "Cancel"))}
                  </button>
                </form>
              <% else %>
                <div>
                  <strong>{Map.get(credential, @fields.label) || "Security Key"}</strong>
                  <%= if Map.get(credential, @fields.backed_up) == true do %>
                    <span class={override_for(@overrides, :synced_badge_class)}>
                      {_gettext(override_for(@overrides, :synced_badge_text, "Synced passkey"))}
                    </span>
                  <% end %>
                  <span class={override_for(@overrides, :timestamp_class)}>
                    <%= if added = @fields.added_at && Map.get(credential, @fields.added_at) do %>
                      Added: {Calendar.strftime(added, "%B %d, %Y")}
                    <% end %>
                    <%= if last_used = Map.get(credential, @fields.last_used_at) do %>
                      | Last used: {Calendar.strftime(last_used, "%B %d, %Y %H:%M")}
                    <% end %>
                  </span>
                </div>
                <div>
                  <button
                    phx-click="edit-label"
                    phx-value-id={credential_id}
                    phx-value-label={Map.get(credential, @fields.label)}
                    phx-target={@myself}
                    class={override_for(@overrides, :rename_button_class)}
                  >
                    {_gettext(override_for(@overrides, :rename_button_text, "Rename"))}
                  </button>
                  <button
                    phx-click="delete-credential"
                    phx-value-id={credential_id}
                    phx-target={@myself}
                    class={override_for(@overrides, :delete_button_class)}
                    data-confirm={_gettext("Are you sure you want to remove this security key?")}
                  >
                    {_gettext(override_for(@overrides, :delete_button_text, "Delete"))}
                  </button>
                </div>
              <% end %>
            </li>
          <% end %>
        </ul>
      <% end %>

      <%= if @strategy.add_credential_enabled? do %>
        <div id={"#{@id}-add-key"} phx-hook="WebAuthnRegistrationHook" phx-target={@myself}>
          <form
            id={"#{@id}-add-key-form"}
            phx-change="update-key-name"
            phx-submit="add-credential"
            phx-target={@myself}
            class={override_for(@overrides, :add_form_class)}
          >
            <%= if override_for(@overrides, :show_key_name_field, true) do %>
              <Input.key_name_field
                id={"#{@id}-key-name"}
                value={@key_name_value}
                overrides={@overrides}
                gettext_fn={@gettext_fn}
              />
            <% end %>
            <button
              type="submit"
              class={override_for(@overrides, :add_button_class)}
              disabled={@adding}
            >
              {_gettext(override_for(@overrides, :add_button_text, "+ Add another security key"))}
            </button>

            <%= if @cross_device? do %>
              <Input.cross_device_button
                disabled={@adding}
                overrides={@overrides}
                gettext_fn={@gettext_fn}
              />
            <% end %>
          </form>
        </div>
      <% end %>

      <%= if @continue_path && @credentials != [] do %>
        <a
          href={@continue_path}
          class={override_for(@overrides, :continue_button_class)}
        >
          {_gettext(override_for(@overrides, :continue_button_text, "Continue"))}
        </a>
      <% end %>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("edit-label", %{"id" => id} = params, socket) do
    {:noreply, assign(socket, editing_id: id, editing_label: params["label"] || "")}
  end

  def handle_event("cancel-edit", _params, socket) do
    {:noreply, assign(socket, editing_id: nil, editing_label: "")}
  end

  def handle_event("save-label", %{"credential_id" => id, "label" => label}, socket) do
    case find_credential(socket, id) do
      nil ->
        {:noreply, assign(socket, error_message: "Credential not found.")}

      credential ->
        strategy = socket.assigns.strategy

        case WebAuthn.Actions.update_credential_label(
               strategy,
               primary_key_value(credential, socket.assigns.fields),
               label,
               tenant: socket.assigns.current_tenant
             ) do
          {:ok, _} ->
            socket =
              socket
              |> assign(editing_id: nil, editing_label: "", error_message: nil)
              |> load_credentials()

            {:noreply, socket}

          {:error, _} ->
            {:noreply, assign(socket, error_message: "Failed to rename credential.")}
        end
    end
  end

  def handle_event("delete-credential", %{"id" => id}, socket) do
    case find_credential(socket, id) do
      nil ->
        {:noreply, assign(socket, error_message: "Credential not found.")}

      credential ->
        strategy = socket.assigns.strategy
        user = socket.assigns.current_user

        case WebAuthn.Actions.delete_credential(
               strategy,
               user,
               primary_key_value(credential, socket.assigns.fields),
               tenant: socket.assigns.current_tenant
             ) do
          :ok ->
            socket = socket |> assign(error_message: nil) |> load_credentials()
            {:noreply, socket}

          {:error, _} ->
            warning =
              override_for(
                socket.assigns.overrides,
                :last_credential_warning,
                "Cannot delete your last security key. You would be locked out."
              )

            {:noreply, assign(socket, error_message: warning)}
        end
    end
  end

  def handle_event("update-key-name", params, socket) do
    {:noreply,
     assign(socket, :key_name_value, Map.get(params, "key_name", socket.assigns.key_name_value))}
  end

  def handle_event("add-credential", params, socket) do
    strategy = socket.assigns.strategy
    user = socket.assigns.current_user

    # Ask before the browser prompt whether this user may add a passkey
    # right now. The strategy checks again when the credential is stored,
    # but by then the user has already touched their authenticator.
    case RecentAuthentication.check(strategy, user, authentication_opts(socket)) do
      :ok -> start_add_ceremony(socket, params)
      {:error, error} -> refuse_add(socket, error)
    end
  end

  # The ceremony timed out (or never started) before the browser answered;
  # the strategy would refuse the stale challenge, and must not be handed a
  # missing one.
  def handle_event(
        "registration-attestation",
        _params,
        %{assigns: %{add_challenge: nil}} = socket
      ) do
    {:noreply,
     assign(socket,
       adding: false,
       error_message: override_for(socket.assigns.overrides, :expired_text, @expired_text)
     )}
  end

  def handle_event("registration-attestation", params, socket) do
    socket = cancel_timer(socket)
    strategy = socket.assigns.strategy
    challenge = socket.assigns.add_challenge
    user = socket.assigns.current_user
    tenant = socket.assigns.current_tenant

    # A blank label is passed as `nil` so the credential resource's
    # attribute default applies.
    label =
      case socket.assigns.key_name_value do
        "" -> nil
        key_name -> key_name
      end

    add_params = %{
      "attestation_object" => params["attestation_object"],
      "client_data_json" => params["client_data_json"],
      "label" => label,
      "transports" => params["transports"],
      "cred_props" => params["cred_props"]
    }

    opts =
      [
        challenge: challenge,
        user: user,
        tenant: tenant,
        user_handle: socket.assigns[:add_user_handle]
      ] ++ authentication_opts(socket)

    case WebAuthn.Actions.add_credential(strategy, add_params, opts) do
      {:ok, _credential} ->
        socket =
          socket
          |> assign(adding: false, add_challenge: nil, error_message: nil, key_name_value: "")
          |> load_credentials()

        {:noreply, socket}

      # The authentication window lapsed while the ceremony was in flight.
      {:error, %AuthenticationFailed{caused_by: %{module: RecentAuthentication}} = error} ->
        refuse_add(socket, error)

      {:error, _} ->
        {:noreply,
         assign(socket,
           adding: false,
           add_challenge: nil,
           error_message: "Failed to register new key."
         )}
    end
  end

  def handle_event("registration-error", params, socket) do
    socket = cancel_timer(socket)

    # `excludeCredentials` makes the browser reject an already-enrolled
    # authenticator client-side with InvalidStateError.
    error_message =
      case params["name"] do
        "InvalidStateError" -> "This device is already registered."
        _ -> "Registration was cancelled."
      end

    {:noreply,
     assign(socket,
       adding: false,
       add_challenge: nil,
       error_message: error_message
     )}
  end

  defp start_add_ceremony(socket, params) do
    strategy = socket.assigns.strategy
    tenant = socket.assigns.current_tenant
    user = socket.assigns.current_user
    credentials = socket.assigns.credentials
    key_name = Map.get(params, "key_name", socket.assigns.key_name_value)

    # The origin the ceremony is accepted from is the strategy's own policy,
    # never the request's host (see `AshAuthentication.Strategy.WebAuthn.Origin`).
    {:ok, challenge} = WebAuthn.Actions.registration_challenge(strategy, tenant)

    # For an existing user the handle must be stable so all of their
    # passkeys share it — reuse the one stored with an existing credential
    # (falling back to the primary key). Existing credential ids go in
    # `excludeCredentials` so re-registering an already-enrolled
    # authenticator fails client-side instead of creating a duplicate.
    {user_descriptor, user_handle} =
      PhoenixWebAuthn.actor_user_descriptor(strategy, user, credentials, key_name)

    exclude_ids = Enum.map(credentials, &Map.get(&1, socket.assigns.fields.credential_id))

    # `hints` names the button that submitted the form ("Use a phone or
    # tablet" asks for `hybrid`); the strategy decides whether it is honoured.
    # The options are addressed to the add form's hook element, so a
    # registration form on the same page leaves them alone.
    options =
      strategy
      |> PhoenixWebAuthn.registration_options(
        challenge,
        tenant,
        user_descriptor,
        exclude_ids,
        hints: params["hints"]
      )
      |> PhoenixWebAuthn.target("#{socket.assigns.id}-add-key")

    socket =
      socket
      |> cancel_timer()
      |> assign(:add_challenge, challenge)
      |> assign(:add_user_handle, user_handle)
      |> assign(:ceremony_timer, start_timer(socket, strategy))
      |> assign(:adding, true)
      |> assign(:error_message, nil)
      |> assign(:key_name_value, key_name)
      |> Phoenix.LiveView.push_event("registration-challenge", options)

    {:noreply, socket}
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

  defp ceremony_timed_out(%{assigns: %{add_challenge: nil}} = socket), do: socket

  defp ceremony_timed_out(socket) do
    assign(socket,
      add_challenge: nil,
      ceremony_timer: nil,
      adding: false,
      error_message:
        override_for(
          socket.assigns.overrides,
          :timeout_text,
          "Adding the passkey timed out. Please try again."
        )
    )
  end

  # `RecentAuthentication.check/3` says why it refused in
  # `caused_by.reason`. Only `:stale` is something the user can fix, by
  # authenticating again, so only that one redirects; the other two can't
  # happen through the rendered form and get a plain message.
  defp refuse_add(socket, %AuthenticationFailed{caused_by: %{reason: reason}}) do
    socket = socket |> cancel_timer() |> assign(adding: false, add_challenge: nil)

    case reason do
      :stale ->
        message =
          override_for(
            socket.assigns.overrides,
            :reauthentication_text,
            "Please sign in again to add a passkey."
          )

        socket =
          socket
          |> put_flash(:error, _gettext(message))
          |> push_navigate(to: reauthentication_path(socket))

        {:noreply, socket}

      :disabled ->
        {:noreply, assign(socket, error_message: "Adding a passkey is not enabled.")}

      :foreign_actor ->
        {:noreply, assign(socket, error_message: "A passkey cannot be added to this account.")}
    end
  end

  # With a passkey already registered, the second-factor verify page is the
  # lighter proof: one touch, no primary credential. A user with none yet
  # (the setup flow) can only sign in again.
  defp reauthentication_path(socket) do
    override_for(socket.assigns.overrides, :reauthentication_path) ||
      case socket.assigns do
        %{strategy: %{verify_enabled?: true}, credentials: [_ | _]} -> @default_verify_path
        _ -> @default_sign_in_path
      end
  end

  # The application may know a more recent authentication than the actor's
  # metadata does; the strategy takes the most recent of the two.
  defp authentication_opts(socket) do
    case socket.assigns.authenticated_at do
      %DateTime{} = at -> [authenticated_at: at]
      _ -> []
    end
  end

  defp load_credentials(socket) do
    assign(socket, :credentials, fetch_credentials(socket))
  end

  defp fetch_credentials(socket) do
    strategy = socket.assigns.strategy
    user = socket.assigns.current_user

    case WebAuthn.Actions.list_credentials(strategy, user,
           tenant: socket.assigns[:current_tenant]
         ) do
      {:ok, credentials} -> credentials
      {:error, _} -> []
    end
  end

  defp credential_fields(strategy) do
    %{
      primary_key: ResourceInfo.primary_key(strategy.credential_resource),
      credential_id: WebAuthn.credential_id_field(strategy),
      label: WebAuthn.label_field(strategy),
      last_used_at: WebAuthn.last_used_at_field(strategy),
      backed_up: WebAuthn.backed_up_field(strategy),
      added_at: WebAuthn.created_at_field(strategy)
    }
  end

  # The primary key as the string the rendered buttons and forms carry.
  defp credential_id(credential, fields),
    do: credential |> primary_key_value(fields) |> to_string()

  # Whatever the credential resource's primary key is, as
  # `Actions.update_credential_label/4` and `delete_credential/4` take it.
  defp primary_key_value(credential, %{primary_key: [field]}), do: Map.get(credential, field)

  defp primary_key_value(_credential, %{primary_key: fields}) do
    raise ArgumentError,
          "ManageCredentials expects the credential resource to have a single-attribute " <>
            "primary key, got #{inspect(fields)}"
  end

  defp find_credential(socket, id) when is_binary(id) do
    fields = socket.assigns.fields
    Enum.find(socket.assigns.credentials, &(credential_id(&1, fields) == id))
  end

  defp find_credential(_socket, _id), do: nil
end
