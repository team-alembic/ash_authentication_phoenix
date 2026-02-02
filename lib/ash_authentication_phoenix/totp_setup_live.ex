# SPDX-FileCopyrightText: 2024 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.TotpSetupLive do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    totp_setup_id: "Element ID for the `TotpSetup` LiveComponent.",
    error_class: "CSS class for the error message when user is not authenticated."

  @moduledoc """
  A generic, white-label TOTP setup page for configuring two-factor authentication.

  This live-view is used by authenticated users to set up TOTP on their account.
  It displays a QR code that can be scanned with an authenticator app, and a
  code input field to confirm the setup.

  ## Usage

  Add to your router using the `totp_setup_route/3` macro:

      scope "/", MyAppWeb do
        pipe_through [:browser, :require_authenticated_user]
        totp_setup_route MyApp.Accounts.User, :totp, auth_routes_prefix: "/auth"
      end

  Note: This route should be protected by authentication middleware to ensure
  only authenticated users can access it.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_view
  alias AshAuthentication.Phoenix.Components
  alias Phoenix.LiveView.{Rendered, Socket}

  @doc false
  @impl true
  def mount(_params, session, socket) do
    overrides =
      session
      |> Map.get("overrides", [AshAuthentication.Phoenix.Overrides.Default])

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

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t()
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= if @current_user do %>
        <.live_component
          module={Components.Totp.SetupForm}
          otp_app={@otp_app}
          id={override_for(@overrides, :totp_setup_id, "totp_setup")}
          strategy={@strategy}
          current_user={@current_user}
          auth_routes_prefix={@auth_routes_prefix}
          overrides={@overrides}
          resource={@resource}
          current_tenant={@current_tenant}
          context={@context}
          gettext_fn={@gettext_fn}
        />
      <% else %>
        <p class={override_for(@overrides, :error_class, "text-red-500")}>
          You must be signed in to set up two-factor authentication.
        </p>
      <% end %>
    </div>
    """
  end
end
