# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.RecoveryCodeVerifyLive do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    recovery_code_verify_id: "Element ID for the `VerifyForm` LiveComponent."

  @moduledoc """
  A generic, white-label recovery code verification page.

  This live-view supports two authentication flows:

  ## Token-based Flow (Password -> Recovery Code)

  Used after a user has authenticated with their primary credentials (e.g., password)
  but needs to complete 2FA and cannot access their TOTP authenticator. The `token`
  URL parameter contains a partial authentication token that will be exchanged for a
  full session token after successful recovery code verification.

  ## Step-up Authentication Flow

  Used when an already-authenticated user needs to verify their identity to access
  protected resources. In this mode, no token is required - the verification uses
  the `current_user` from the session.

  ## Usage

  Add to your router using the `recovery_code_verify_route/3` macro:

      scope "/", MyAppWeb do
        pipe_through :browser
        recovery_code_verify_route MyApp.Accounts.User, :recovery_code, auth_routes_prefix: "/auth"
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
        module={Components.RecoveryCode.VerifyForm}
        otp_app={@otp_app}
        id={override_for(@overrides, :recovery_code_verify_id, "recovery_code_verify")}
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
