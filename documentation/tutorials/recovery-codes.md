<!--
SPDX-FileCopyrightText: 2026 Alembic Pty Ltd

SPDX-License-Identifier: MIT
-->

# Recovery Codes (Phoenix Integration)

This guide explains how to add Phoenix UI for recovery code generation and
verification. Recovery codes provide a fallback authentication method when
a user's TOTP authenticator app is unavailable.

## Prerequisites

1. Recovery code strategy configured on your user resource
   (see the [Recovery Codes tutorial](https://hexdocs.pm/ash_authentication/recovery-codes.html))
2. AshAuthentication.Phoenix installed and configured
3. TOTP strategy configured (recovery codes are typically used alongside TOTP)

## Built-in Routes

AshAuthentication.Phoenix provides two router macros for recovery codes:

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    # ...
    plug :load_from_session
    plug :set_actor, :user
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    # Standard auth routes
    auth_routes AuthController, MyApp.Accounts.User, path: "/auth"

    # TOTP routes
    totp_2fa_route MyApp.Accounts.User, :totp, auth_routes_prefix: "/auth"
    totp_setup_route MyApp.Accounts.User, :totp, auth_routes_prefix: "/auth"

    # Recovery code routes
    recovery_code_verify_route MyApp.Accounts.User, :recovery_code, auth_routes_prefix: "/auth"
    recovery_code_display_route MyApp.Accounts.User, :recovery_code, auth_routes_prefix: "/auth"
  end
end
```

### recovery_code_verify_route

Generates a recovery code verification page. Supports two modes:

- **Token-based** (`/recovery-code-verify/:token`) — used after password sign-in
  as a 2FA fallback, when the user clicks "Use a recovery code instead" on the
  TOTP verify page.
- **Step-up** (`/recovery-code-verify`) — used when an already-authenticated user
  needs to re-verify their identity.

### recovery_code_display_route

Generates a page for generating and displaying recovery codes
(`/recovery-codes`). This should be placed behind authentication middleware so
only authenticated users can access it.

### Route Options

Both macros accept the same options:

| Option | Default | Description |
|--------|---------|-------------|
| `path` | `/recovery-code-verify` or `/recovery-codes` | Path to mount at |
| `live_view` | Built-in LiveView | Custom LiveView module |
| `auth_routes_prefix` | — | Prefix for auth routes (e.g. `"/auth"`) |
| `overrides` | `[Default]` | Override modules for customisation |
| `gettext_fn` | — | Translation function as `{module, function}` |
| `gettext_backend` | — | Gettext backend as `{module, domain}` |

## Cross-Linking with TOTP

When both TOTP and recovery codes are configured, the verify pages should
link to each other so users can switch between authentication methods.

Add these overrides to your auth overrides module:

```elixir
# lib/my_app_web/auth_overrides.ex
defmodule MyAppWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  # Show "Use a recovery code instead" on the TOTP verify page
  override AshAuthentication.Phoenix.Components.Totp.Verify2faForm do
    set :recovery_code_link_path, "/recovery-code-verify"
  end

  # Show "Use authenticator app instead" on the recovery code verify page
  override AshAuthentication.Phoenix.Components.RecoveryCode.VerifyForm do
    set :totp_link_path, "/totp-verify"
  end
end
```

> ### Automatic setup with Igniter {: .info}
>
> When using `mix igniter.install ash_authentication_phoenix --auth-strategy recovery_code`,
> these overrides are automatically added to your auth overrides module.

The cross-links automatically preserve the authentication token in the URL, so
users can switch between TOTP and recovery code verification without losing
their session state.

## Auth Controller Integration

When the recovery code strategy is installed via Igniter alongside TOTP, a
`success/4` clause is added to the auth controller that redirects users to the
recovery codes page after completing TOTP setup:

```elixir
# Added automatically by the igniter
def success(conn, {_, :confirm_setup}, user, token) do
  conn
  |> store_in_session(user)
  |> set_live_socket_id(token)
  |> assign(:current_user, user)
  |> redirect(to: ~p"/recovery-codes")
end
```

This ensures users are prompted to generate recovery codes immediately after
setting up their authenticator app.

## Authentication Metadata

After successful recovery code verification, metadata is attached to the user:

```elixir
# Strategies used in this session
user.__metadata__.authentication_strategies
#=> [:recovery_code]

# Timestamp of recovery code verification
user.__metadata__.recovery_code_used_at
#=> ~U[2026-04-09 02:00:00Z]
```

This metadata is persisted in the session and can be used to detect when a
recovery code was used (e.g. to prompt the user to set up a new authenticator).

## Requiring Recovery Codes

### Using the Plug

For controller-based routes:

```elixir
pipeline :require_recovery_codes do
  plug AshAuthentication.Phoenix.Plug.RequireRecoveryCodes,
    resource: MyApp.Accounts.User,
    on_missing: :redirect_to_setup,
    setup_path: "/recovery-codes"
end
```

| Option | Default | Description |
|--------|---------|-------------|
| `resource` | Required | The user resource module |
| `on_missing` | `:halt` | `:halt`, `:redirect_to_setup`, or `{:redirect, path}` |
| `setup_path` | `"/recovery-codes"` | Path to redirect for setup |
| `current_user_assign` | `:current_user` | Assign key for current user |

### Using the LiveView Hook

For LiveView routes:

```elixir
live_session :require_recovery_codes,
  on_mount: [
    {AshAuthentication.Phoenix.LiveSession, :default},
    {AshAuthentication.Phoenix.LiveSession.RequireRecoveryCodes, :require_recovery_codes}
  ] do
  live "/secure", SecureLive
end
```

## Checking Recovery Code Status

Use `RecoveryCodeHelpers` in controllers, LiveViews, and templates:

```elixir
alias AshAuthentication.Phoenix.RecoveryCodeHelpers

# Check if user has recovery codes generated
RecoveryCodeHelpers.recovery_codes_configured?(user)
#=> true

# Check if resource supports recovery codes
RecoveryCodeHelpers.recovery_code_available?(MyApp.Accounts.User)
#=> true

# Get the recovery code strategy
{:ok, strategy} = RecoveryCodeHelpers.get_recovery_code_strategy(MyApp.Accounts.User)
```

## Next Steps

- [TOTP as Second Factor](totp-2fa.md) — setting up TOTP 2FA
- [Recovery Code Security](https://hexdocs.pm/ash_authentication/recovery-code-security.html) — understanding hashing trade-offs and entropy
- [UI Overrides](ui-overrides.md) — customising the recovery code UI
