# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.RecoveryCode.DisplayCodes do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the `h2` element.",
    label_text: "Text for the heading.",
    instructions_class: "CSS class for instructions text.",
    instructions_text: "Instructions text shown above the codes.",
    codes_grid_class: "CSS class for the grid of recovery codes.",
    code_item_class: "CSS class for individual code items.",
    warning_class: "CSS class for the warning text.",
    warning_text: "Warning text shown after generating codes.",
    generate_button_text: "Text for the generate button.",
    generate_button_class: "CSS class for the generate button.",
    confirm_button_text: "Text for the confirmation button.",
    confirm_button_class: "CSS class for the confirmation button.",
    confirm_path: "Path to redirect to after confirming codes have been saved.",
    error_class: "CSS class for error messages."

  @moduledoc """
  Generates and displays recovery codes for the authenticated user.

  This component handles the full lifecycle of recovery code generation:

  1. Shows a "Generate new codes" button initially
  2. On click, calls the strategy's generate action directly
  3. Displays the plaintext codes in a grid
  4. Shows a confirmation button that redirects to a configurable path

  ## Component hierarchy

  This is rendered by `AshAuthentication.Phoenix.RecoveryCodeDisplayLive`.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Strategy}
  alias Phoenix.LiveView.{Rendered, Socket}

  @doc false
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
      |> assign_new(:codes, fn -> nil end)
      |> assign_new(:error, fn -> nil end)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <h2 class={override_for(@overrides, :label_class)}>
        {_gettext(override_for(@overrides, :label_text))}
      </h2>

      <p class={override_for(@overrides, :instructions_class)}>
        {_gettext(override_for(@overrides, :instructions_text))}
      </p>

      <%= if @error do %>
        <div class={override_for(@overrides, :error_class)}>
          {_gettext(@error)}
        </div>
      <% end %>

      <%= if @codes do %>
        <div class={override_for(@overrides, :codes_grid_class)}>
          <%= for code <- @codes do %>
            <div class={override_for(@overrides, :code_item_class)}>
              <code>{code}</code>
            </div>
          <% end %>
        </div>

        <p class={override_for(@overrides, :warning_class)}>
          {_gettext(override_for(@overrides, :warning_text))}
        </p>

        <.link
          navigate={override_for(@overrides, :confirm_path, "/")}
          class={override_for(@overrides, :confirm_button_class)}
        >
          {_gettext(override_for(@overrides, :confirm_button_text, "I've saved my codes"))}
        </.link>
      <% else %>
        <button
          phx-click="generate"
          phx-target={@myself}
          class={override_for(@overrides, :generate_button_class)}
        >
          {_gettext(override_for(@overrides, :generate_button_text, "Generate new codes"))}
        </button>
      <% end %>
    </div>
    """
  end

  @doc false
  @impl true
  @spec handle_event(String.t(), map, Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("generate", _params, socket) do
    strategy = socket.assigns.strategy
    user = socket.assigns.current_user
    domain = Info.authentication_domain!(strategy.resource)

    opts = [
      domain: domain,
      tenant: socket.assigns.current_tenant,
      context: %{private: %{ash_authentication?: true}}
    ]

    case Strategy.action(strategy, :generate, %{user: user}, opts) do
      {:ok, updated_user} ->
        codes = Ash.Resource.get_metadata(updated_user, :recovery_codes) || []
        {:noreply, assign(socket, codes: codes, error: nil)}

      {:error, _error} ->
        {:noreply, assign(socket, error: "Failed to generate recovery codes.")}
    end
  end
end
