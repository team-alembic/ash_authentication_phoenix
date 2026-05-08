# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.WebAuthn.Support do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root element.",
    unsupported_message: "Message shown when WebAuthn is not supported by the browser."

  @moduledoc """
  Detects WebAuthn browser support via a JS hook.

  Renders a hidden element that triggers the `WebAuthnSupportHook` on mount.
  Sends `{:passkeys_supported, boolean}` to the parent LiveView.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:passkeys_supported, fn -> nil end)
      |> assign_new(:conditional_ui_available, fn -> false end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <span
      id={@id}
      class={override_for(@overrides, :root_class)}
      phx-hook="WebAuthnSupportHook"
      style="display:none"
    />
    """
  end

  @impl true
  def handle_event("passkeys-supported", %{"supported" => supported}, socket) do
    send(self(), {:passkeys_supported, supported})
    {:noreply, assign(socket, :passkeys_supported, supported)}
  end

  def handle_event("conditional-ui-available", %{"available" => available}, socket) do
    send(self(), {:conditional_ui_available, available})
    {:noreply, assign(socket, :conditional_ui_available, available)}
  end
end
