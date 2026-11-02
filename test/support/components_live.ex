# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Test.ComponentsLive do
  @moduledoc false
  use Phoenix.LiveView, layout: {AshAuthentication.Phoenix.Test.HomeLive, :live}
  alias AshAuthentication.Phoenix.Components

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:auth_routes_prefix, session["auth_routes_prefix"])

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Sign-in component with minimal attributes --%>
    <.live_component module={Components.SignIn} id="sign-in" auth_routes_prefix={@auth_routes_prefix} />
    """
  end
end

defmodule AshAuthentication.Phoenix.Test.WebAuthnManageLive do
  @moduledoc """
  Renders `ManageCredentials` for the signed-in user against a variant of
  the User resource's WebAuthn strategy, so the add-credential gating can
  be exercised without a resource per configuration.

  The `:variant` path segment picks the strategy options; an
  `authenticated_at` query parameter (ISO 8601) is passed through to the
  component as the application-known authentication time.
  """
  use Phoenix.LiveView, layout: {AshAuthentication.Phoenix.Test.HomeLive, :live}
  alias AshAuthentication.Info
  alias AshAuthentication.Phoenix.Components

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    strategy = Info.strategy!(Example.Accounts.User, :webauthn)

    strategy =
      case params["variant"] do
        "disabled" ->
          %{strategy | add_credential_enabled?: false}

        "recent" ->
          %{strategy | add_credential_max_authentication_age: {5, :minutes}}

        "recent-second" ->
          %{strategy | add_credential_max_authentication_age: 1}

        "recent-no-verify" ->
          %{strategy | add_credential_max_authentication_age: 60, verify_enabled?: false}

        "hybrid" ->
          %{
            strategy
            | hints: [:hybrid, :security_key],
              timeout: 300_000,
              allow_hint_override?: true
          }

        "quick" ->
          %{strategy | timeout: 100}

        _ ->
          strategy
      end

    authenticated_at =
      case params["authenticated_at"] do
        nil ->
          nil

        iso8601 ->
          {:ok, at, _offset} = DateTime.from_iso8601(iso8601)
          at
      end

    {:ok, assign(socket, strategy: strategy, authenticated_at: authenticated_at)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.live_component
      module={Components.WebAuthn.ManageCredentials}
      id="manage"
      strategy={@strategy}
      current_user={@current_user}
      authenticated_at={@authenticated_at}
    />
    """
  end
end

defmodule AshAuthentication.Phoenix.Test.WebAuthnVerifyVariantLive do
  @moduledoc """
  Renders `Verify2faForm` in step-up mode for the signed-in user against a
  variant of the User resource's WebAuthn strategy.
  """
  use Phoenix.LiveView, layout: {AshAuthentication.Phoenix.Test.HomeLive, :live}
  alias AshAuthentication.Info
  alias AshAuthentication.Phoenix.Components

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    strategy = Info.strategy!(Example.Accounts.User, :webauthn)

    strategy =
      case params["variant"] do
        "hybrid" ->
          %{
            strategy
            | hints: [:hybrid, :security_key],
              timeout: 300_000,
              allow_hint_override?: true
          }

        "quick" ->
          %{strategy | timeout: 100}

        "no-verify" ->
          %{strategy | verify_enabled?: false}

        _ ->
          strategy
      end

    {:ok, assign(socket, strategy: strategy)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.live_component
      module={Components.WebAuthn.Verify2faForm}
      id="verify"
      mode={:step_up}
      token={nil}
      current_user={@current_user}
      strategy={@strategy}
      resource={Example.Accounts.User}
      auth_routes_prefix="/auth"
    />
    """
  end
end
