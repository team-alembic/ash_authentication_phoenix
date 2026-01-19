<!--
SPDX-FileCopyrightText: 2024 Alembic Pty Ltd

SPDX-License-Identifier: MIT
-->

# TOTP as Second Factor (2FA)

This guide explains how to use TOTP as a second authentication factor, requiring users to verify with both their password and an authenticator app code.

## Overview

Two-factor authentication (2FA) adds an extra layer of security by requiring two different forms of verification:

1. **Something you know** - Password
2. **Something you have** - Authenticator app (TOTP)

With 2FA enabled, users sign in with their password first, then verify with a TOTP code.

## Prerequisites

Ensure you have:

1. Password authentication configured
2. TOTP strategy configured in your user resource
3. Tokens enabled for your authentication setup

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshAuthentication],
    domain: MyApp.Accounts

  authentication do
    tokens do
      enabled? true
      token_resource MyApp.Accounts.Token
      signing_secret MyApp.Secrets
    end

    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
        sign_in_tokens_enabled? true
      end

      totp do
        identity_field :email
        issuer "MyApp"
        # For 2FA, sign_in_enabled? can be false (TOTP is verification only)
        sign_in_enabled? false
        confirm_setup_enabled? true
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false
    attribute :hashed_password, :string, allow_nil?: true, sensitive?: true
    attribute :totp_secret, :binary, allow_nil?: true, sensitive?: true
    attribute :last_totp_at, :datetime, allow_nil?: true, sensitive?: true
  end
end
```

## Requiring TOTP for Routes

### Using the RequireTotp Plug

For controller-based routes, use the `RequireTotp` plug to enforce TOTP configuration:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Phoenix.Plug.RequireTotp

  pipeline :require_totp do
    plug :require_totp,
      resource: MyApp.Accounts.User,
      on_missing: :redirect,
      redirect_to: "/auth/totp/setup"
  end

  scope "/", MyAppWeb do
    pipe_through [:browser, :require_totp]

    # Routes that require TOTP to be configured
    get "/settings", SettingsController, :index
    get "/admin", AdminController, :index
  end
end
```

### Plug Options

| Option | Description | Default |
|--------|-------------|---------|
| `resource` | The user resource module | Required |
| `current_user_assign` | Assign key for current user | `:current_user` |
| `on_missing` | Action when TOTP not configured: `:redirect` or `:halt` | `:redirect` |
| `redirect_to` | Path to redirect when TOTP missing | `"/auth/totp/setup"` |

### Using the RequireTotp LiveView Hook

For LiveView routes, use the `RequireTotp` on_mount hook:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Phoenix.LiveSession.RequireTotp

  scope "/", MyAppWeb do
    pipe_through :browser

    ash_authentication_live_session :protected,
      on_mount: [{AshAuthentication.Phoenix.LiveSession.RequireTotp, :require_totp}] do
      live "/dashboard", DashboardLive
      live "/settings", SettingsLive
    end
  end
end
```

### Hook Options

Pass options as a tuple:

```elixir
on_mount: [{AshAuthentication.Phoenix.LiveSession.RequireTotp,
  {:require_totp,
    setup_path: "/setup-2fa",
    current_user_assign: :actor
  }}]
```

| Option | Description | Default |
|--------|-------------|---------|
| `setup_path` | Path to redirect for TOTP setup | `"/auth/totp/setup"` |
| `current_user_assign` | Assign key for current user | `:current_user` |

## Hard-Required 2FA with Auth Controller

For applications that require TOTP verification immediately after password sign-in (before accessing any authenticated route), use a custom auth controller callback combined with session tracking.

### Custom Auth Controller

Override the `success/4` callback to check TOTP status after password authentication:

```elixir
defmodule MyAppWeb.AuthController do
  use MyAppWeb, :controller
  use AshAuthentication.Phoenix.Controller

  alias AshAuthentication.Phoenix.TotpHelpers

  def success(conn, {:password, _strategy}, user, _token) do
    if TotpHelpers.totp_configured?(user, user.__struct__) do
      conn
      |> put_session(:awaiting_totp_verification, true)
      |> put_session(:totp_user_id, user.id)
      |> redirect(to: ~p"/auth/totp/verify")
    else
      conn
      |> store_in_session(user)
      |> assign(:current_user, user)
      |> redirect(to: ~p"/")
    end
  end

  def success(conn, {:totp, _strategy}, user, _token) do
    conn
    |> delete_session(:awaiting_totp_verification)
    |> delete_session(:totp_user_id)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: ~p"/")
  end

  def success(conn, _activity, user, _token) do
    conn
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: ~p"/")
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_flash(:error, "Authentication failed")
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: ~p"/")
  end
end
```

### Companion Plug for TOTP Verification

Create a plug that blocks access until TOTP is verified:

```elixir
defmodule MyAppWeb.Plugs.RequireTotpVerification do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    cond do
      get_session(conn, :awaiting_totp_verification) ->
        conn
        |> put_flash(:info, "Please verify your identity")
        |> redirect(to: "/auth/totp/verify")
        |> halt()

      true ->
        conn
    end
  end
end
```

### Router Configuration

Use the plug in your authenticated pipeline:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :require_totp_verified do
    plug MyAppWeb.Plugs.RequireTotpVerification
  end

  scope "/auth", MyAppWeb do
    pipe_through :browser

    auth_routes AuthController, MyApp.Accounts.User, path: "/"

    # TOTP verify page must be accessible during verification
    get "/totp/verify", TotpVerifyController, :show
    post "/totp/verify", TotpVerifyController, :verify
  end

  scope "/", MyAppWeb do
    pipe_through [:browser, :require_authenticated, :require_totp_verified]

    # All protected routes
    get "/", PageController, :home
    get "/dashboard", DashboardController, :index
  end
end
```

### TOTP Verify Controller

```elixir
defmodule MyAppWeb.TotpVerifyController do
  use MyAppWeb, :controller

  alias AshAuthentication.Info

  def show(conn, _params) do
    if get_session(conn, :awaiting_totp_verification) do
      render(conn, :verify)
    else
      redirect(conn, to: ~p"/")
    end
  end

  def verify(conn, %{"code" => code}) do
    user_id = get_session(conn, :totp_user_id)
    {:ok, user} = MyApp.Accounts.get_user_by_id(user_id)
    {:ok, strategy} = Info.strategy(user.__struct__, :totp)

    case AshAuthentication.Strategy.action(strategy, :sign_in, %{
      strategy.identity_field => Map.get(user, strategy.identity_field),
      :code => code
    }) do
      {:ok, verified_user} ->
        conn
        |> delete_session(:awaiting_totp_verification)
        |> delete_session(:totp_user_id)
        |> store_in_session(verified_user)
        |> assign(:current_user, verified_user)
        |> redirect(to: ~p"/")

      {:error, _} ->
        conn
        |> put_flash(:error, "Invalid code")
        |> redirect(to: ~p"/auth/totp/verify")
    end
  end
end
```

This pattern ensures that:

1. Password authentication succeeds but doesn't grant full access
2. The user is redirected to TOTP verification
3. All protected routes check for completed TOTP verification
4. Only after TOTP verification does the user get full session access

## Authentication Metadata

When users authenticate, metadata is attached to track which authentication strategies were used:

```elixir
# After password sign-in
user.__metadata__.authentication_strategies
#=> [:password]

# After TOTP sign-in
user.__metadata__.authentication_strategies
#=> [:totp]

# After TOTP verification (includes timestamp)
user.__metadata__.totp_verified_at
#=> ~U[2024-01-15 10:30:00Z]
```

### Checking Authentication Status

Use the `TotpHelpers` module to check TOTP status:

```elixir
alias AshAuthentication.Phoenix.TotpHelpers

# Check if user has TOTP configured
TotpHelpers.totp_configured?(user, MyApp.Accounts.User)
#=> true

# Check if resource supports TOTP
TotpHelpers.totp_available?(MyApp.Accounts.User)
#=> true

# Get the TOTP strategy
{:ok, strategy} = TotpHelpers.get_totp_strategy(MyApp.Accounts.User)
```

## TOTP Setup Page

Create a dedicated page for users to set up TOTP:

```elixir
# lib/my_app_web/live/totp_setup_live.ex
defmodule MyAppWeb.TotpSetupLive do
  use MyAppWeb, :live_view

  alias AshAuthentication.Phoenix.Components.Totp.SetupForm

  def mount(_params, _session, socket) do
    {:ok, strategy} = AshAuthentication.Info.strategy(MyApp.Accounts.User, :totp)
    {:ok, assign(socket, strategy: strategy)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto mt-8">
      <h1 class="text-2xl font-bold mb-4">Set Up Two-Factor Authentication</h1>

      <.live_component
        module={SetupForm}
        id="totp-setup"
        strategy={@strategy}
        current_user={@current_user}
      />
    </div>
    """
  end
end
```

Add the route:

```elixir
scope "/", MyAppWeb do
  pipe_through :browser

  ash_authentication_live_session :authenticated,
    on_mount: [{MyAppWeb.LiveUserAuth, :live_user_required}] do
    live "/auth/totp/setup", TotpSetupLive
  end
end
```

## Checking TOTP in Controllers

For custom logic in controllers:

```elixir
defmodule MyAppWeb.SettingsController do
  use MyAppWeb, :controller
  alias AshAuthentication.Phoenix.TotpHelpers

  def index(conn, _params) do
    user = conn.assigns.current_user
    totp_configured = TotpHelpers.totp_configured?(user, MyApp.Accounts.User)

    render(conn, :index, totp_configured: totp_configured)
  end
end
```

## Checking TOTP in LiveViews

For LiveView components:

```elixir
defmodule MyAppWeb.SettingsLive do
  use MyAppWeb, :live_view
  alias AshAuthentication.Phoenix.TotpHelpers

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    totp_configured = TotpHelpers.totp_configured?(user, MyApp.Accounts.User)

    {:ok, assign(socket, totp_configured: totp_configured)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h2>Security Settings</h2>

      <%= if @totp_configured do %>
        <p class="text-green-600">✓ Two-factor authentication is enabled</p>
      <% else %>
        <p class="text-yellow-600">⚠ Two-factor authentication is not set up</p>
        <.link navigate={~p"/auth/totp/setup"} class="btn">
          Set up 2FA
        </.link>
      <% end %>
    </div>
    """
  end
end
```

## Creating a Custom on_mount Hook

For more control over 2FA requirements:

```elixir
defmodule MyAppWeb.Require2FA do
  import Phoenix.Component
  import Phoenix.LiveView
  alias AshAuthentication.Phoenix.TotpHelpers

  def on_mount(:require_2fa, _params, _session, socket) do
    user = socket.assigns[:current_user]

    cond do
      is_nil(user) ->
        {:halt, redirect(socket, to: "/sign-in")}

      not TotpHelpers.totp_configured?(user, MyApp.Accounts.User) ->
        socket =
          socket
          |> put_flash(:error, "Please set up two-factor authentication to continue")
          |> redirect(to: "/auth/totp/setup")
        {:halt, socket}

      true ->
        {:cont, assign(socket, :totp_configured, true)}
    end
  end

  def on_mount(:optional_2fa, _params, _session, socket) do
    user = socket.assigns[:current_user]
    configured = user && TotpHelpers.totp_configured?(user, MyApp.Accounts.User)
    {:cont, assign(socket, :totp_configured, configured || false)}
  end
end
```

Use in router:

```elixir
ash_authentication_live_session :admin,
  on_mount: [{MyAppWeb.Require2FA, :require_2fa}] do
  live "/admin", AdminLive
end

ash_authentication_live_session :user,
  on_mount: [{MyAppWeb.Require2FA, :optional_2fa}] do
  live "/dashboard", DashboardLive
end
```

## Grace Period for Setup

Allow users a grace period to set up 2FA:

```elixir
defmodule MyAppWeb.Require2FAWithGrace do
  import Phoenix.Component
  import Phoenix.LiveView
  alias AshAuthentication.Phoenix.TotpHelpers

  @grace_period_days 7

  def on_mount(:require_2fa_with_grace, _params, _session, socket) do
    user = socket.assigns[:current_user]

    cond do
      is_nil(user) ->
        {:halt, redirect(socket, to: "/sign-in")}

      TotpHelpers.totp_configured?(user, MyApp.Accounts.User) ->
        {:cont, assign(socket, :totp_configured, true)}

      within_grace_period?(user) ->
        socket =
          socket
          |> assign(:totp_configured, false)
          |> assign(:grace_period_remaining, days_remaining(user))
          |> put_flash(:warning, "Please set up 2FA within #{days_remaining(user)} days")
        {:cont, socket}

      true ->
        socket =
          socket
          |> put_flash(:error, "Two-factor authentication is now required")
          |> redirect(to: "/auth/totp/setup")
        {:halt, socket}
    end
  end

  defp within_grace_period?(user) do
    days_remaining(user) > 0
  end

  defp days_remaining(user) do
    created = user.inserted_at
    deadline = DateTime.add(created, @grace_period_days, :day)
    DateTime.diff(deadline, DateTime.utc_now(), :day) |> max(0)
  end
end
```

## Security Best Practices

### Enforce TOTP for Sensitive Operations

Even if a user has authenticated with password + TOTP, consider requiring fresh TOTP verification for sensitive operations:

```elixir
defmodule MyAppWeb.AdminLive do
  use MyAppWeb, :live_view

  def handle_event("delete_user", %{"id" => id}, socket) do
    # Require recent TOTP verification for destructive actions
    if recent_totp_verification?(socket.assigns.current_user) do
      # Proceed with deletion
      {:noreply, socket}
    else
      {:noreply,
        socket
        |> put_flash(:error, "Please verify your identity with your authenticator app")
        |> push_navigate(to: "/verify-identity?return_to=/admin")}
    end
  end

  defp recent_totp_verification?(user) do
    case user.__metadata__[:totp_verified_at] do
      nil -> false
      verified_at -> DateTime.diff(DateTime.utc_now(), verified_at, :minute) < 15
    end
  end
end
```

### Backup Codes

Consider implementing backup codes for users who lose access to their authenticator app. This is not built into `ash_authentication` by default but can be implemented as a custom strategy.

### Account Recovery

Have a process for users who lose both their password and TOTP access. This typically involves identity verification through support channels.

## Next Steps

- [TOTP Authentication](totp.md) - Using TOTP as primary authentication
- [LiveView Integration](liveview.md) - Setting up authentication in LiveView
- [UI Overrides](ui-overrides.md) - Customising authentication UI
