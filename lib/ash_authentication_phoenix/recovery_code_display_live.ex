# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.RecoveryCodeDisplayLive do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    recovery_code_display_id: "Element ID for the `DisplayCodes` LiveComponent.",
    error_class: "CSS class for error messages when unauthenticated."

  @moduledoc """
  A generic, white-label page for generating and displaying recovery codes.

  This page is used by authenticated users to generate recovery codes as a
  backup authentication method. It should be placed behind authentication
  middleware to ensure only authenticated users can access it.

  ## Usage

  Add to your router using the `recovery_code_display_route/3` macro:

      scope "/", MyAppWeb do
        pipe_through [:browser, :require_authenticated_user]
        recovery_code_display_route MyApp.Accounts.User, :recovery_code, auth_routes_prefix: "/auth"
      end

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
          module={Components.RecoveryCode.DisplayCodes}
          id={override_for(@overrides, :recovery_code_display_id, "recovery_code_display")}
          current_user={@current_user}
          strategy={@strategy}
          overrides={@overrides}
          current_tenant={@current_tenant}
          context={@context}
          gettext_fn={@gettext_fn}
        />
      <% else %>
        <p class={override_for(@overrides, :error_class)}>
          {_gettext("You must be signed in to manage recovery codes.")}
        </p>
      <% end %>
    </div>
    """
  end
end
