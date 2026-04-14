<!--
SPDX-FileCopyrightText: 2026 Alembic Pty Ltd

SPDX-License-Identifier: MIT
-->

# WebAuthn / Passkey Authentication

WebAuthn lets users sign in with hardware security keys (YubiKey), platform authenticators (Touch ID, Windows Hello, Face ID), or passkeys. This guide covers end-to-end setup: backend strategy, Phoenix components, and the JavaScript hooks required for the WebAuthn ceremony.

## Overview

WebAuthn authentication has more moving parts than other strategies because the browser participates in the cryptographic ceremony. At a high level:

1. The server issues a **challenge** (registration or authentication).
2. The browser invokes `navigator.credentials.create` / `.get` with the challenge.
3. The authenticator (hardware key, platform biometric) signs the challenge.
4. The server verifies the signed response and creates/authenticates the user.

`ash_authentication_phoenix` provides the Phoenix components and JavaScript hooks that drive this flow against an `AshAuthentication.Strategy.WebAuthn` backend.

## Prerequisites

Before using the WebAuthn UI components, you need to configure the WebAuthn strategy in your user resource. See the [AshAuthentication WebAuthn guide](https://hexdocs.pm/ash_authentication/webauthn.html) for the backend setup.

At minimum, your user resource should have a WebAuthn strategy configured with a credential resource:

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshAuthentication],
    domain: MyApp.Accounts

  authentication do
    strategies do
      webauthn do
        credential_resource MyApp.Accounts.WebAuthnCredential
        rp_id "localhost"
        rp_name "MyApp"
        registration_enabled? true
      end
    end
  end
end
```

The `credential_resource` is a separate Ash resource that stores each registered credential (public key, sign count, label, etc.).

## Router setup

WebAuthn uses the same `sign_in_route` macro as other strategies. No additional configuration is needed — the `SignIn` component auto-discovers the WebAuthn strategy and renders the appropriate child component:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    # ...
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    sign_in_route auth_routes_prefix: "/auth", on_mount: [{MyAppWeb.LiveUserAuth, :live_no_user}]
  end
end
```

## JavaScript hooks

WebAuthn requires LiveView hooks to invoke the browser's credential APIs. You must register three hooks in your `assets/js/app.js`:

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

The hooks communicate with the server via `push_event` / `handle_event` — you don't need to write any custom JavaScript.

## Origin and `rp_id` configuration

The `rp_id` (Relying Party ID) must be a **hostname only** — never include the scheme or port. The browser derives the effective domain from the page origin and checks that the `rp_id` is either equal to it or a registrable suffix of it.

| Environment | Page URL                     | Correct `rp_id`      | Common mistake                 |
| ----------- | ---------------------------- | -------------------- | ------------------------------ |
| Local dev   | `http://localhost:4000`      | `"localhost"`        | `"localhost:4000"` (has port)  |
| Staging     | `https://staging.example.com` | `"staging.example.com"` or `"example.com"` | `"https://staging.example.com"` (has scheme) |
| Production  | `https://example.com`        | `"example.com"`      | `"https://example.com"`        |

**Local development gotcha**: Phoenix serves on `http://localhost:4000` by default, and it's tempting to set `rp_id "localhost:4000"` to "match" that. Don't — WebAuthn will reject it with a `SecurityError` because `rp_id` is a [domain string](https://www.w3.org/TR/webauthn-2/#rp-id), not an origin. The port (and scheme) are part of the origin, which the browser validates separately; `rp_id` is only the domain. Use `"localhost"` in dev and let the browser handle the port match on its own.

WebAuthn over plain HTTP is only allowed when the origin is `localhost` or `127.0.0.1` — any other hostname requires HTTPS, even in development.

Credentials registered against one `rp_id` cannot be used with a different one — changing it invalidates existing credentials. Pick your production `rp_id` carefully (bare apex like `"example.com"` is usually safer than `"www.example.com"` because it covers subdomains).

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
