<!--
SPDX-FileCopyrightText: 2026 Alembic Pty Ltd

SPDX-License-Identifier: MIT
-->

# WebAuthn / Passkey Authentication

WebAuthn lets users sign in with hardware security keys (YubiKey), platform authenticators (Touch ID, Windows Hello, Face ID), or passkeys. This guide covers end-to-end setup for using a passkey as the **primary** authentication credential — backend strategy, Phoenix components, and the JavaScript hooks required for the WebAuthn ceremony.

> ### Looking for second-factor (2FA) setup? {: .info}
>
> If you want a passkey to act as a *second* factor on top of an existing
> primary credential (typically a password), see the
> [Passkeys as 2FA](webauthn-2fa.md) guide. The same WebAuthn strategy
> supports both modes via the `--mode` installer flag.

## Overview

WebAuthn authentication has more moving parts than other strategies because the browser participates in the cryptographic ceremony. At a high level:

1. The server issues a **challenge** (registration or authentication).
2. The browser invokes `navigator.credentials.create` / `.get` with the challenge.
3. The authenticator (hardware key, platform biometric) signs the challenge.
4. The server verifies the signed response and creates/authenticates the user.

`ash_authentication_phoenix` provides the Phoenix components and JavaScript hooks that drive this flow against an `AshAuthentication.Strategy.WebAuthn` backend.

## Installation

The installer wires the strategy, credential resource, JS hooks, and
configuration in a single step. Run from your Phoenix project root:

```bash
mix ash_authentication_phoenix.add_strategy webauthn
```

That defaults to `--mode primary` — passkeys as the user's primary
credential. For passkey-as-second-factor instead, pass `--mode 2fa` and
follow the [Passkeys as 2FA](webauthn-2fa.md) guide.

The installer is idempotent — re-running it will not duplicate config or
overwrite changes you've made by hand.

## Prerequisites

If you're configuring the strategy by hand instead of using the installer,
see the [AshAuthentication WebAuthn guide](https://hexdocs.pm/ash_authentication/webauthn.html)
for the backend setup. At minimum, your user resource needs a WebAuthn
strategy with a credential resource. The installer-generated form
threads `rp_id`, `rp_name`, and `origin` through the user's `Secrets`
module so they can be set per-environment via the application
environment:

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
      webauthn do
        credential_resource MyApp.Accounts.WebAuthnCredential
        rp_id MyApp.Secrets
        rp_name MyApp.Secrets
        origin MyApp.Secrets
        identity_field :email
      end
    end
  end
end
```

Static literals (`rp_id "example.com"`, etc.) are still accepted; the
Secrets-module form is what the installer uses by default.

The `credential_resource` is a separate Ash resource that stores each
registered credential (public key, sign count, label, etc.).

## Router setup

WebAuthn uses the same `sign_in_route` macro as other strategies — the
installer slots it into your existing scope automatically. The `SignIn`
component auto-discovers the WebAuthn strategy and renders the registration /
authentication forms beside any other strategies you have configured:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    # ...
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    sign_in_route auth_routes_prefix: "/auth",
      on_mount: [{MyAppWeb.LiveUserAuth, :live_no_user}]
  end
end
```

## JavaScript hooks

WebAuthn requires LiveView hooks to invoke the browser's credential APIs.
The installer wires this into your `assets/js/app.js` automatically. If
you're doing it by hand:

```javascript
import {
  WebAuthnRegistrationHook,
  WebAuthnAuthenticationHook,
  WebAuthnSupportHook
} from "ash_authentication_phoenix/priv/static/webauthn_hooks.js"

const Hooks = {
  WebAuthnRegistrationHook,
  WebAuthnAuthenticationHook,
  WebAuthnSupportHook
}

const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks
})
```

Each hook drives a different part of the ceremony:

- **`WebAuthnSupportHook`** — Detects whether the browser supports WebAuthn and conditionally shows/hides the passkey UI.
- **`WebAuthnRegistrationHook`** — Handles the `navigator.credentials.create` call during registration (new passkey).
- **`WebAuthnAuthenticationHook`** — Handles the `navigator.credentials.get` call during sign-in.

The hooks communicate with the server via `pushEventTo` / `handle_event`
— you don't need to write any custom JavaScript.

## Origin and `rp_id` configuration

The installer seeds three application-environment-driven settings on the
strategy via the user's `Secrets` module:

| Setting              | What it is                                | Dev seed (`config/dev.exs`) | Prod seed (`config/runtime.exs`) |
| -------------------- | ----------------------------------------- | --------------------------- | -------------------------------- |
| `:webauthn_rp_id`    | Domain only (Relying Party ID)            | `"localhost"`               | `System.get_env("WEBAUTHN_RP_ID")` |
| `:webauthn_rp_name`  | Display name shown in the browser prompt  | humanised app name          | `System.get_env("WEBAUTHN_RP_NAME")` |
| `:webauthn_origin`   | Optional explicit origin override         | *(unset)*                   | `System.get_env("WEBAUTHN_ORIGIN")` |

When `:webauthn_origin` is unset the strategy uses the request origin —
`scheme://host[:port]` derived from `socket.host_uri` (LiveView) or the
`Plug.Conn` (controllers). That keeps dev "just work" against whatever
port Phoenix is on (`4000`, `4001`, …) without anyone editing config.
Set `:webauthn_origin` explicitly in prod (or any env where you don't
want to trust the request origin) to enforce a known value.

**`rp_id` must be a hostname** — no scheme, no port. WebAuthn rejects
`"localhost:4000"` or `"https://example.com"` with a `SecurityError`
because `rp_id` is a [domain string](https://www.w3.org/TR/webauthn-2/#rp-id),
not an origin. The browser validates the origin (scheme + host + port)
separately against the page URL.

WebAuthn over plain HTTP is only allowed when the host is `localhost` or
`127.0.0.1`. Any other hostname requires HTTPS, even in development.

Credentials registered against one `rp_id` are bound to it — changing
`rp_id` later invalidates existing credentials. Pick your production
`rp_id` carefully (a bare apex like `"example.com"` covers subdomains;
`"www.example.com"` is more restrictive).

## Credential management

The library ships with a `ManageCredentials` component that lets authenticated users add, rename, and remove their passkeys:

```heex
<.live_component
  module={AshAuthentication.Phoenix.Components.WebAuthn.ManageCredentials}
  id="webauthn-credentials"
  strategy={@webauthn_strategy}
  current_user={@current_user}
/>
```

Deletion of the last credential is prevented to avoid locking users out of their accounts. All credential operations route through `AshAuthentication.Strategy.WebAuthn.Actions`, so policies, hooks, and validations defined on the credential resource are honored.

## Cross-device sign-in (QR / hybrid)

A passkey stored on a phone can be used to sign in on a laptop that has no authenticator of its own. The browser shows a QR code, the phone scans it, and the ceremony completes over Bluetooth proximity plus a relay — the phone never needs a route to your application, so this works on `localhost` in development.

None of that is yours to implement. It is hybrid transport, handled entirely by the browser and the phone's operating system, and the assertion it produces is indistinguishable from one made by a USB security key. The only thing to do is ask for it, by setting `hints` on the strategy in your `ash_authentication` configuration:

```elixir
webauthn :webauthn do
  credential_resource MyApp.Accounts.WebAuthnCredential
  hints [:hybrid, :security_key]
  timeout 300_000
end
```

`:hybrid` is the "use your phone or tablet" option, `:security_key` a removable USB/NFC key, `:client_device` the authenticator built into this machine. The list is an order of preference. The components carry it into both the registration and the sign-in ceremony, so a machine with no authenticator can enrol a phone passkey and then use it.

Raise the `timeout`. The default 60 seconds cannot fit a QR scan, a Bluetooth handshake and a prompt on the second device, and the ceremony expires mid-scan; `ash_authentication` warns at compile time if you offer `:hybrid` with less than 120 seconds.

Chrome 128+ honours `hints`. Other browsers ignore members they don't recognise and fall back to their own picker, which generally offers the same thing — no feature detection is needed.

## Customization

All WebAuthn components support the standard override mechanism. You can customize button text, CSS classes, and icons via your overrides module:

```elixir
defmodule MyAppWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.Components.WebAuthn.AuthenticationForm do
    set :button_text, "Sign in with your security key"
  end
end
```

See [UI Overrides](ui-overrides.md) for the full list of overridable slots.

## Troubleshooting

- **"SecurityError" / "The relying party ID is not a registrable domain suffix"** — Your `rp_id` includes a port (e.g. `"localhost:4000"`) or a scheme (e.g. `"https://example.com"`). Strip it to the bare hostname.
- **"NotAllowedError" in the browser** — Usually a mismatch between `rp_id` and the page origin, or the user cancelled the prompt.
- **WebAuthn prompt never appears in dev** — You're serving over plain HTTP from a hostname other than `localhost` / `127.0.0.1`. Either use `localhost` or run dev over HTTPS.
- **Credentials missing after deploy** — The `rp_id` likely changed. Credentials are bound to the exact `rp_id` they were registered under.
- **Hooks not firing** — Verify all three hooks are registered in `app.js` and that the LiveView is using them. Check the browser console for hook initialization errors.
- **"Failed to register new key"** — Check that the `credential_resource` exists and that the `:create` action accepts the credential attributes.
