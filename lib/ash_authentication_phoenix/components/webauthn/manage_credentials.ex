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
    timestamp_class: "CSS class for timestamp text."

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
      |> assign_new(:current_tenant, fn -> nil end)

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
                <form phx-submit="save-label" phx-target={@myself}>
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
                  <span class={override_for(@overrides, :timestamp_class)}>
                    Added: {Calendar.strftime(credential.inserted_at, "%B %d, %Y")}
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
        <button
          phx-click="add-credential"
          phx-target={@myself}
          class={override_for(@overrides, :add_button_class)}
          disabled={@adding}
        >
          {_gettext(override_for(@overrides, :add_button_text, "+ Add another security key"))}
        </button>
      </div>
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

  def handle_event("add-credential", _params, socket) do
    strategy = socket.assigns.strategy
    tenant = socket.assigns.current_tenant

    {:ok, challenge} = WebAuthn.Actions.registration_challenge(strategy, tenant)

    rp_id = WebAuthn.Helpers.resolve_rp_id(strategy, tenant)
    rp_name = WebAuthn.Helpers.resolve_rp_name(strategy, tenant)
    user_id = Base.url_encode64(:crypto.strong_rand_bytes(64), padding: false)
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:add_challenge, challenge)
      |> assign(:adding, true)
      |> Phoenix.LiveView.push_event("registration-challenge", %{
        challenge: Base.url_encode64(challenge.bytes, padding: false),
        rp_id: rp_id,
        rp_name: rp_name,
        user_id: user_id,
        user_name: to_string(Map.get(user, strategy.identity_field)),
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
    challenge = socket.assigns.add_challenge
    user = socket.assigns.current_user
    tenant = socket.assigns.current_tenant

    add_params = %{
      "attestation_object" => params["attestation_object"],
      "client_data_json" => params["client_data_json"],
      "label" => "New Key"
    }

    case WebAuthn.Actions.add_credential(strategy, add_params,
           challenge: challenge,
           user: user,
           tenant: tenant
         ) do
      {:ok, _credential} ->
        socket =
          socket
          |> assign(adding: false, add_challenge: nil, error_message: nil)
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

  def handle_event("registration-error", _params, socket) do
    {:noreply,
     assign(socket,
       adding: false,
       add_challenge: nil,
       error_message: "Registration was cancelled."
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
