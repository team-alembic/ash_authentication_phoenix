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

## Built-in TOTP Routes

AshAuthentication.Phoenix provides two router macros for TOTP functionality that handle common use cases:

### totp_2fa_route

Generates a TOTP verification page for two-factor authentication. Use this after primary authentication (e.g., password sign-in) when the user has TOTP enabled.

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
    plug :set_actor, :user
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    # Standard auth routes
    auth_routes AuthController, MyApp.Accounts.User, path: "/auth"

    # TOTP verification route - defaults to /totp-verify
    totp_2fa_route MyApp.Accounts.User, :totp, auth_routes_prefix: "/auth"

    # TOTP setup route - defaults to /totp-setup
    totp_setup_route MyApp.Accounts.User, :totp, auth_routes_prefix: "/auth"
  end
end
```

> ### Browser pipeline {: .info}
>
> The `plug :set_actor, :user` is required in the browser pipeline for TOTP
> verification to work. The `load_from_session` plug loads the user from the
> session into `conn.assigns`, and `set_actor` makes it available to the TOTP
> verify action via `Ash.PlugHelpers.get_actor/1`.

Options for both macros:
- `path` - The path to mount at (defaults to `/totp-verify` and `/totp-setup`)
- `live_view` - Custom LiveView module
- `auth_routes_prefix` - Prefix for auth routes (e.g., `"/auth"`). **Required** for the form action URLs to work correctly.
- `overrides` - Override modules for customisation

Options:
- `path` - The path to mount at (default: `/totp-setup`)
- `live_view` - Custom LiveView module (default: `AshAuthentication.Phoenix.TotpSetupLive`)
- `auth_routes_prefix` - Prefix for auth routes
- `overrides` - Override modules for customisation

### Automatic Route Insertion

When using the igniter installer (`mix igniter.install ash_authentication_phoenix --auth-strategy totp`), the TOTP routes are automatically added to your router's browser scope alongside the other auth routes. You can also add them manually to an existing project.

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

## 2FA with Auth Controller

When using the igniter installer with `--auth-strategy magic_link,totp` (or `password,totp`), the TOTP strategy task automatically generates auth controller clauses that handle the 2FA flow. Here's how the generated code works:

### Generated Auth Controller Clauses

The installer adds two `success/4` clauses before the default catch-all:

```elixir
defmodule MyAppWeb.AuthController do
  use MyAppWeb, :controller
  use AshAuthentication.Phoenix.Controller

  # Sign-in interception: check if TOTP is configured
  def success(conn, {_, phase} = _activity, user, token)
      when phase in [:sign_in, :sign_in_with_token] do
    return_to = get_session(conn, :return_to) || ~p"/"

    if AshAuthentication.Phoenix.TotpHelpers.totp_configured?(user) do
      # TOTP is set up — store user in session and redirect to verify
      conn
      |> store_in_session(user)
      |> set_live_socket_id(token)
      |> assign(:current_user, user)
      |> put_session(:return_to, return_to)
      |> redirect(to: ~p"/totp-verify/#{token}")
    else
      # No TOTP configured — redirect to setup
      conn
      |> store_in_session(user)
      |> set_live_socket_id(token)
      |> assign(:current_user, user)
      |> put_session(:return_to, return_to)
      |> redirect(to: ~p"/totp-setup")
    end
  end

  # Registration: always redirect to TOTP setup
  def success(conn, {_, :register}, user, token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> store_in_session(user)
    |> set_live_socket_id(token)
    |> assign(:current_user, user)
    |> put_session(:return_to, return_to)
    |> redirect(to: ~p"/totp-setup")
  end

  # Default catch-all for other auth activities
  def success(conn, activity, user, token) do
    # ... standard success handling
  end

  # ...
end
```

### How the flow works

1. **Sign-in**: When a user signs in (via password or magic link), the first clause matches `:sign_in` or `:sign_in_with_token`. It stores the user in session, then checks if TOTP is configured:
   - **TOTP configured**: redirects to `/totp-verify/:token` where the built-in `TotpVerifyLive` presents the code entry form
   - **TOTP not configured**: redirects to `/totp-setup` where the built-in `TotpSetupLive` shows the QR code setup flow

2. **Registration**: New users (e.g., via magic link with `registration_enabled? true`) match the `:register` clause and are always redirected to TOTP setup.

3. **TOTP verification**: The user is already in the session (so `plug :load_from_session` and `plug :set_actor, :user` find them). The verify form submits to the TOTP strategy's verify action, which checks the code. On success, the controller's catch-all `success/4` runs and redirects to the return path.

> ### Why store_in_session before verify? {: .info}
>
> The user is stored in session before TOTP verification so that the verify
> plug can find the user via `get_actor(conn)`. The `RequireTotp` plug or
> LiveView hook can be used on protected routes to ensure TOTP verification
> has been completed before granting access to sensitive resources.

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
TotpHelpers.totp_configured?(user)
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
    totp_configured = TotpHelpers.totp_configured?(user)

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
    totp_configured = TotpHelpers.totp_configured?(user)

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

      not TotpHelpers.totp_configured?(user) ->
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
    configured = user && TotpHelpers.totp_configured?(user)
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

      TotpHelpers.totp_configured?(user) ->
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
