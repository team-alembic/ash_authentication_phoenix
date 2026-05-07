# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.WebAuthnSetupLive do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    webauthn_setup_id: "Element ID for the `ManageCredentials` LiveComponent."

  @moduledoc """
  A generic, white-label WebAuthn passkey setup page for second-factor flows.

  Wraps `AshAuthentication.Phoenix.Components.WebAuthn.ManageCredentials` —
  authenticated users can register a new passkey, see existing credentials,
  rename them, or revoke them.

  Mounted by the `webauthn_setup_route/3` router macro (default path
  `/webauthn-setup`). Pair with `Plug.RequireAuthenticated` (or your
  equivalent) so only signed-in users hit it.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_view
  alias AshAuthentication.Phoenix.Components
  alias Phoenix.LiveView.{Rendered, Socket}

  @impl true
  def mount(_params, session, socket) do
    overrides =
      Map.get(session, "overrides", [AshAuthentication.Phoenix.Overrides.Default])

    socket =
      socket
      |> assign(overrides: overrides)
      |> assign_new(:otp_app, fn -> nil end)
      |> assign(:current_tenant, session["tenant"])
      |> assign(:context, session["context"] || %{})
      |> assign(:auth_routes_prefix, session["auth_routes_prefix"])
      |> assign(:gettext_fn, session["gettext_fn"])
      |> assign(:strategy, session["strategy"])
      |> assign(:resource, session["resource"])

    {:ok, socket}
  end

  @impl true
  @spec render(Socket.assigns()) :: Rendered.t()
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= if @current_user && @strategy do %>
        <.live_component
          module={Components.WebAuthn.ManageCredentials}
          id={override_for(@overrides, :webauthn_setup_id, "webauthn_setup")}
          strategy={@strategy}
          current_user={@current_user}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />
      <% else %>
        <p>You must be signed in to manage your passkeys.</p>
      <% end %>
    </div>
    """
  end
end
