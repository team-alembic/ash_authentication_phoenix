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
      "Whether to show a passkey name input before adding a new credential, so the name is set before the browser ceremony stores it in the user's password manager. Defaults to `true`."

  @moduledoc """
  Credential management panel for authenticated users.

  Displays all registered security keys/passkeys with options to rename,
  delete, and add new credentials.

  Prevents deletion of the last credential.

  All credential operations go through `AshAuthentication.Strategy.WebAuthn.Actions`
  — the Ash resource layer is never bypassed.

  ## Props

    * `strategy` - The WebAuthn strategy configuration. Required.
    * `current_user` - The authenticated user. Required.
    * `overrides` - A list of override modules.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.Phoenix.Components.WebAuthn.Input
  alias AshAuthentication.Phoenix.WebAuthn, as: PhoenixWebAuthn
  alias AshAuthentication.Strategy.WebAuthn
  # alias Phoenix.LiveView.{Rendered, Socket}

  @impl true
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
      |> assign_new(:key_name_value, fn -> "" end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:continue_path, fn -> nil end)

    unless assigns[:current_user] do
      raise ArgumentError, "ManageCredentials requires a :current_user assign"
    end

    socket = assign_new(socket, :credentials, fn -> fetch_credentials(socket) end)

    {:ok, socket}
  end

  @impl true
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
          <%= for credential <- @credentials do %>
            <li class={override_for(@overrides, :credential_item_class)}>
              <%= if @editing_id == credential.id do %>
                <form
                  id={"credential-#{credential.id}-form"}
                  phx-submit="save-label"
                  phx-target={@myself}
                >
                  <input type="hidden" name="credential_id" value={credential.id} />
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
                  <strong>{credential.label || "Security Key"}</strong>
                  <%= if Map.get(credential, @strategy.backed_up_field) == true do %>
                    <span class={override_for(@overrides, :synced_badge_class)}>
                      {_gettext(override_for(@overrides, :synced_badge_text, "Synced passkey"))}
                    </span>
                  <% end %>
                  <span class={override_for(@overrides, :timestamp_class)}>
                    <%= if added = Map.get(credential, :inserted_at) do %>
                      Added: {Calendar.strftime(added, "%B %d, %Y")}
                    <% end %>
                    <%= if credential.last_used_at do %>
                      | Last used: {Calendar.strftime(credential.last_used_at, "%B %d, %Y %H:%M")}
                    <% end %>
                  </span>
                </div>
                <div>
                  <button
                    phx-click="edit-label"
                    phx-value-id={credential.id}
                    phx-value-label={credential.label}
                    phx-target={@myself}
                    class={override_for(@overrides, :rename_button_class)}
                  >
                    {_gettext(override_for(@overrides, :rename_button_text, "Rename"))}
                  </button>
                  <button
                    phx-click="delete-credential"
                    phx-value-id={credential.id}
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

      <div id={"#{@id}-add-key"} phx-hook="WebAuthnRegistrationHook">
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
        </form>
      </div>

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

  @impl true
  def handle_event("edit-label", %{"id" => id, "label" => label}, socket) do
    {:noreply, assign(socket, editing_id: id, editing_label: label || "")}
  end

  def handle_event("cancel-edit", _params, socket) do
    {:noreply, assign(socket, editing_id: nil, editing_label: "")}
  end

  def handle_event("save-label", %{"credential_id" => id, "label" => label}, socket) do
    if Enum.any?(socket.assigns.credentials, &(to_string(&1.id) == id)) do
      strategy = socket.assigns.strategy

      case WebAuthn.Actions.update_credential_label(strategy, id, label,
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
    else
      {:noreply, assign(socket, error_message: "Credential not found.")}
    end
  end

  def handle_event("delete-credential", %{"id" => id}, socket) do
    if Enum.any?(socket.assigns.credentials, &(to_string(&1.id) == id)) do
      strategy = socket.assigns.strategy
      user = socket.assigns.current_user

      case WebAuthn.Actions.delete_credential(strategy, user, id,
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
    else
      {:noreply, assign(socket, error_message: "Credential not found.")}
    end
  end

  def handle_event("update-key-name", params, socket) do
    {:noreply,
     assign(socket, :key_name_value, Map.get(params, "key_name", socket.assigns.key_name_value))}
  end

  def handle_event("add-credential", params, socket) do
    strategy = socket.assigns.strategy
    tenant = socket.assigns.current_tenant
    origin = PhoenixWebAuthn.origin_from_socket(socket)

    {:ok, challenge} =
      WebAuthn.Actions.registration_challenge(strategy, tenant, origin: origin)

    user = socket.assigns.current_user
    credentials = socket.assigns.credentials
    key_name = Map.get(params, "key_name", socket.assigns.key_name_value)

    # For an existing user the handle must be stable so all of their
    # passkeys share it — reuse the one stored with an existing credential
    # (falling back to the primary key). Existing credential ids go in
    # `excludeCredentials` so re-registering an already-enrolled
    # authenticator fails client-side instead of creating a duplicate.
    {user_descriptor, user_handle} =
      PhoenixWebAuthn.actor_user_descriptor(strategy, user, credentials, key_name)

    exclude_ids = Enum.map(credentials, &Map.get(&1, strategy.credential_id_field))

    options =
      PhoenixWebAuthn.registration_options(
        strategy,
        challenge,
        tenant,
        user_descriptor,
        exclude_ids
      )

    socket =
      socket
      |> assign(:add_challenge, challenge)
      |> assign(:add_user_handle, user_handle)
      |> assign(:adding, true)
      |> assign(:key_name_value, key_name)
      |> Phoenix.LiveView.push_event("registration-challenge", options)

    {:noreply, socket}
  end

  def handle_event("registration-attestation", params, socket) do
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

    case WebAuthn.Actions.add_credential(strategy, add_params,
           challenge: challenge,
           user: user,
           tenant: tenant,
           user_handle: socket.assigns[:add_user_handle]
         ) do
      {:ok, _credential} ->
        socket =
          socket
          |> assign(adding: false, add_challenge: nil, error_message: nil, key_name_value: "")
          |> load_credentials()

        {:noreply, socket}

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
end
