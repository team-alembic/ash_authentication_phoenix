<!--
SPDX-FileCopyrightText: 2024 Alembic Pty Ltd

SPDX-License-Identifier: MIT
-->

# TOTP Authentication

TOTP (Time-based One-Time Password) provides secure authentication using authenticator apps like Google Authenticator, Authy, or 1Password. This guide covers how to use TOTP with `ash_authentication_phoenix`.

## Overview

TOTP can be used in two ways:

1. **Primary Authentication** - Users sign in with their email and a TOTP code (no password required)
2. **Second Factor (2FA)** - Users sign in with password first, then verify with TOTP

This guide covers primary authentication. For 2FA setup, see [TOTP as Second Factor](totp-2fa.md).

## Prerequisites

Before using TOTP UI components, you need to configure the TOTP strategy in your user resource. See the [AshAuthentication TOTP guide](https://hexdocs.pm/ash_authentication/totp.html) for details on setting up the backend.

Your user resource should have:

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
      totp do
        identity_field :email
        issuer "MyApp"
        sign_in_enabled? true
        # Optional: require confirmation before storing secret
        confirm_setup_enabled? true
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false
    attribute :totp_secret, :binary, allow_nil?: true, sensitive?: true
    attribute :last_totp_at, :datetime, allow_nil?: true, sensitive?: true
  end

  identities do
    identity :unique_email, [:email]
  end
end
```

## Automatic Component Rendering

When TOTP is configured with `sign_in_enabled? true`, the sign-in page automatically renders the TOTP sign-in form alongside other authentication methods.

The TOTP components include:

- **Sign-in form** - Email and 6-digit code input
- **Setup form** - QR code display and code confirmation

## Router Configuration

No special router configuration is needed for primary TOTP authentication. The standard `sign_in_route` and `auth_routes` macros handle TOTP automatically:

```elixir
scope "/", MyAppWeb do
  pipe_through :browser

  auth_routes AuthController, MyApp.Accounts.User, path: "/auth"
  sign_in_route(auth_routes_prefix: "/auth")
end
```

## Sign-In Flow

When a user visits the sign-in page:

1. They see the TOTP sign-in form with email and code fields
2. They enter their email address
3. They open their authenticator app and enter the current 6-digit code
4. On submit, the code is validated against their stored secret
5. On success, they receive a session token and are signed in

## Setup Flow

Users need to set up TOTP before they can use it to sign in. The setup process:

1. User navigates to a dedicated TOTP setup page (while authenticated)
2. The setup form generates a secret and displays a QR code
3. User scans the QR code with their authenticator app
4. User enters the current code to confirm setup
5. On successful confirmation, the secret is stored

### Setup Page

TOTP setup requires authentication, so it should be on a dedicated page separate from the sign-in page. Create a LiveView for TOTP setup:

```elixir
# lib/my_app_web/live/totp_setup_live.ex
defmodule MyAppWeb.TotpSetupLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, strategy} = AshAuthentication.Info.strategy(MyApp.Accounts.User, :totp)
    {:ok, assign(socket, strategy: strategy)}
  end

  def render(assigns) do
    ~H\"\"\"
    <div class="max-w-md mx-auto mt-8">
      <h1 class="text-2xl font-bold mb-4">Set Up Two-Factor Authentication</h1>

      <.live_component
        module={AshAuthentication.Phoenix.Components.Totp.SetupForm}
        id="totp-setup"
        strategy={@strategy}
        current_user={@current_user}
      />
    </div>
    \"\"\"
  end
end
```

Add the route (protected by authentication):

```elixir
scope "/", MyAppWeb do
  pipe_through [:browser, :require_authenticated_user]

  live "/settings/totp", TotpSetupLive
end
```

## Customising the UI

### Overrides

You can customise the TOTP components using the override system. Create or update your overrides module:

```elixir
defmodule MyAppWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.Components.Totp do
    set :root_class, "totp-wrapper"
  end

  override AshAuthentication.Phoenix.Components.Totp.SignInForm do
    set :label, "Sign in with Authenticator"
    set :button_text, "Verify & Sign In"
  end

  override AshAuthentication.Phoenix.Components.Totp.SetupForm do
    set :qr_code_class, "mx-auto my-4"
    set :instructions_text, "Scan this QR code with your authenticator app"
  end

  override AshAuthentication.Phoenix.Components.Totp.Input do
    set :code_input_label, "6-digit code"
    set :code_input_placeholder, "000000"
  end
end
```

Then reference your overrides in the router:

```elixir
sign_in_route(
  auth_routes_prefix: "/auth",
  overrides: [MyAppWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
)
```

### Available Override Options

#### Totp (Wrapper Component)

| Option | Description | Default |
|--------|-------------|---------|
| `root_class` | CSS class for wrapper div | `nil` |
| `sign_in_toggle_text` | Text for sign-in toggle link | `"Sign in with code"` |
| `setup_toggle_text` | Text for setup toggle link | `"Set up authenticator"` |

#### Totp.SignInForm

| Option | Description | Default |
|--------|-------------|---------|
| `root_class` | CSS class for form wrapper | `nil` |
| `label` | Form heading text | `"Sign in with TOTP"` |
| `submit_label` | Submit button text | `"Sign In"` |
| `disable_button_text` | Button text while submitting | `"Signing in..."` |

#### Totp.SetupForm

| Option | Description | Default |
|--------|-------------|---------|
| `root_class` | CSS class for form wrapper | `nil` |
| `qr_code_class` | CSS class for QR code container | `nil` |
| `instructions_text` | Instructions shown above QR code | `"Scan this QR code..."` |
| `confirm_label` | Confirm button text | `"Confirm"` |
| `valid_code_class` | CSS class when code is valid | `"text-green-600"` |
| `invalid_code_class` | CSS class when code is invalid | `"text-red-600"` |

#### Totp.Input

| Option | Description | Default |
|--------|-------------|---------|
| `code_input_label` | Label for code input | `"Authentication Code"` |
| `code_input_placeholder` | Placeholder for code input | `"000000"` |
| `identity_input_label` | Label for identity input | `"Email"` |

## Security Considerations

### Replay Protection

TOTP codes can only be used once. After successful authentication, the `last_totp_at` field is updated to prevent replay attacks where the same code is used multiple times within its validity period.

### Secret Storage

The TOTP secret is stored as binary data in the database. This is necessary because the application must be able to read the secret to generate QR codes during setup and to validate codes during sign-in. Mark the attribute with `sensitive?: true` to prevent it from appearing in logs, but note this does not encrypt the data at rest. For additional protection, consider using database-level encryption or application-layer encryption if your security requirements demand it.

### Encrypting Secrets with AshCloak

For application-layer encryption of TOTP secrets, you can use [AshCloak](https://hex.pm/packages/ash_cloak). AshCloak encrypts data before storing it in the database and decrypts it when accessed.

Since AshCloak stores encrypted data in an attribute but exposes the decrypted value via a calculation, you need to configure TOTP to read from the calculation:

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshAuthentication, AshCloak],
    domain: MyApp.Accounts

  cloak do
    vault MyApp.Vault

    attributes [:totp_secret]

    decrypt :decrypted_totp_secret, attribute: :totp_secret, type: :binary
  end

  authentication do
    strategies do
      totp do
        identity_field :email
        issuer "MyApp"
        # The encrypted secret is stored here
        secret_field :totp_secret
        # But we read from the decrypted calculation
        read_secret_from :decrypted_totp_secret
        sign_in_enabled? true
        confirm_setup_enabled? true
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false
    # Encrypted secret - AshCloak will encrypt this automatically
    attribute :totp_secret, :binary, allow_nil?: true, sensitive?: true
    attribute :last_totp_at, :datetime, allow_nil?: true, sensitive?: true
  end
end
```

Create a vault module for AshCloak:

```elixir
defmodule MyApp.Vault do
  use Cloak.Vault, otp_app: :my_app

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers,
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1",
          key: decode_env!("CLOAK_KEY"),
          iv_length: 12
        }
      )

    {:ok, config}
  end

  defp decode_env!(var) do
    var
    |> System.get_env()
    |> Base.decode64!()
  end
end
```

With this configuration:
- `secret_field` specifies where the encrypted secret is written
- `read_secret_from` specifies the calculation that returns the decrypted value
- AshCloak handles encryption/decryption transparently

### Brute Force Protection

Consider implementing rate limiting on TOTP verification to prevent brute force attacks. The TOTP strategy supports configurable brute force protection:

```elixir
totp do
  # ... other config
  brute_force_strategy {:preparation, MyApp.TotpRateLimiter}
end
```

## Troubleshooting

### QR Code Not Displaying

Ensure that:
1. The `eqrcode` library is available (included with `ash_authentication`)
2. Your Content Security Policy allows inline SVG images

### Code Validation Failing

Common causes:
1. **Time drift** - Ensure the server and authenticator app clocks are synchronised
2. **Already used** - Each code can only be used once per period (default 30 seconds)
3. **Wrong secret** - User may need to re-scan the QR code

### Form Not Appearing

Check that:
1. TOTP strategy is configured with `sign_in_enabled? true`
2. The user resource is correctly referenced in `auth_routes`
3. Overrides are properly configured if customising

## Next Steps

- [TOTP as Second Factor](totp-2fa.md) - Add TOTP as a second authentication factor
- [UI Overrides](ui-overrides.md) - Comprehensive guide to customising authentication UI
- [LiveView Integration](liveview.md) - Setting up authentication in LiveView
