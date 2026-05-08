# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.WebAuthnVerifyLive do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    webauthn_verify_id: "Element ID for the `WebAuthnVerify` LiveComponent."

  @moduledoc """
  A generic, white-label WebAuthn second-factor verification page.

  Two flows are supported:

  ## Token flow (primary → second factor)

  Used right after a primary sign-in (e.g. password) when the user has a
  passkey registered. The `:token` URL parameter is the short-lived JWT issued
  by the primary strategy; this page performs the WebAuthn ceremony and
  exchanges the verified token for a session.

  ## Step-up flow

  Used by an already-signed-in user re-asserting their second factor for a
  sensitive operation. No token is required — the page reads the
  `current_user` from the session.

  ## Usage

      scope "/", MyAppWeb do
        pipe_through :browser
        webauthn_2fa_route MyApp.Accounts.User, :webauthn, auth_routes_prefix: "/auth"
      end

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
  @spec handle_params(map, String.t(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_params(params, _uri, socket) do
    token = params["token"]

    mode =
      cond do
        token && token != "" -> :token
        socket.assigns[:current_user] -> :step_up
        true -> :error
      end

    {:noreply, socket |> assign(:token, token) |> assign(:mode, mode)}
  end

  @impl true
  @spec render(Socket.assigns()) :: Rendered.t()
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <.live_component
        module={Components.WebAuthn.Verify2faForm}
        otp_app={@otp_app}
        id={override_for(@overrides, :webauthn_verify_id, "webauthn_verify")}
        token={@token}
        mode={@mode}
        current_user={@current_user}
        strategy={@strategy}
        resource={@resource}
        auth_routes_prefix={@auth_routes_prefix}
        overrides={@overrides}
        current_tenant={@current_tenant}
        context={@context}
        gettext_fn={@gettext_fn}
      />
    </div>
    """
  end
end
