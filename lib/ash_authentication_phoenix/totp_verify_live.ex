# SPDX-FileCopyrightText: 2024 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.TotpVerifyLive do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    totp_verify_id: "Element ID for the `TotpVerify` LiveComponent."

  @moduledoc """
  A generic, white-label TOTP verification page for two-factor authentication.

  This live-view supports two authentication flows:

  ## Token-based Flow (Password → TOTP)

  Used after a user has authenticated with their primary credentials (e.g., password)
  but still needs to complete TOTP verification. The `token` URL parameter contains
  a partial authentication token that will be exchanged for a full session token
  after successful TOTP verification.

  ## Step-up Authentication Flow

  Used when an already-authenticated user needs to verify their TOTP code to access
  protected resources. In this mode, no token is required - the verification uses
  the `current_user` from the session.

  ## Usage

  Add to your router using the `totp_2fa_route/1` macro:

      scope "/", MyAppWeb do
        pipe_through :browser
        totp_2fa_route MyApp.Accounts.User, :totp, auth_routes_prefix: "/auth"
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
  @spec handle_params(map, String.t(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_params(params, _uri, socket) do
    token = params["token"]

    # Determine the verification mode:
    # - If token is present, use token-based flow (password → TOTP)
    # - If no token but current_user exists, use step-up flow
    mode =
      cond do
        token && token != "" -> :token
        socket.assigns[:current_user] -> :step_up
        true -> :error
      end

    socket =
      socket
      |> assign(:token, token)
      |> assign(:mode, mode)

    {:noreply, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t()
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <.live_component
        module={Components.Totp.Verify2faForm}
        otp_app={@otp_app}
        id={override_for(@overrides, :totp_verify_id, "totp_verify")}
        token={@token}
        mode={@mode}
        current_user={@current_user}
        strategy={@strategy}
        auth_routes_prefix={@auth_routes_prefix}
        overrides={@overrides}
        resource={@resource}
        current_tenant={@current_tenant}
        context={@context}
        gettext_fn={@gettext_fn}
      />
    </div>
    """
  end
end
