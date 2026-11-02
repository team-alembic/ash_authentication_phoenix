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
        # Optional allowlist; unset, any origin on the rp_id is accepted.
        origin MyApp.Secrets
        identity_field :email
      end
    end
  end
end
```

Static literals (`rp_id "example.com"`, etc.) are still accepted; the
Secrets-module form is what the installer uses by default. See
[Origin and `rp_id` configuration](#origin-and-rp_id-configuration) for
what each setting does, and why `origin` is usually best left unset.

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
— you don't need to write any custom JavaScript. The options a component
pushes are the strategy's own (`timeout`, `hints`, `userVerification`,
`attestation`, …) and reach `navigator.credentials` unchanged; nothing is
defaulted in the browser. Each push is addressed to the component that
asked for it, so a page may hold several ceremony components — two
strategies, or a credential manager beside a registration form — without
one starting the other's browser prompt.

## Sign-in uses discoverable credentials

The sign-in challenge never lists credentials. It is issued before anyone
is authenticated, and listing the credentials of a submitted email address
would tell whoever typed it whether the account exists and what its
credential ids are. So `allowCredentials` is always empty, the browser
offers the passkeys it holds for the site, and the credential id resolves
the user — in identity mode as much as in passkey-first mode. An identity
submitted with the sign-in is optional and only has to match the
credential's owner; the `AuthenticationForm` hides the input by default
(`show_identity_field`).

Two things follow:

- Only **discoverable** credentials (passkeys, resident keys) can sign in.
  Keep the strategy's `resident_key :required`, which is the default;
  `ash_authentication` warns at compile time if a strategy that signs users
  in would let an authenticator create a non-discoverable credential.
  `:preferred` and `:discouraged` are only for a second-factor-only strategy
  (`sign_in_enabled? false`), whose verify challenge lists the
  authenticated user's credentials so that both kinds can answer.
- There is no "enter your email to find your passkey" step to build. The
  browser's own picker, or passkey autofill (conditional UI), is the path.

See "Discoverable and non-discoverable credentials" in the
[AshAuthentication WebAuthn guide](https://hexdocs.pm/ash_authentication/webauthn.html)
for the background.

## Origin and `rp_id` configuration

The installer seeds three application-environment-driven settings on the
strategy via the user's `Secrets` module:

| Setting              | What it is                                | Dev seed (`config/dev.exs`) | Prod seed (`config/runtime.exs`) |
| -------------------- | ----------------------------------------- | --------------------------- | -------------------------------- |
| `:webauthn_rp_id`    | Domain only (Relying Party ID)            | `"localhost"`               | `System.get_env("WEBAUTHN_RP_ID")` |
| `:webauthn_rp_name`  | Display name shown in the browser prompt  | humanised app name          | `System.get_env("WEBAUTHN_RP_NAME")` |
| `:webauthn_origin`   | Optional exact allowlist of origins       | *(unset)*                   | `System.get_env("WEBAUTHN_ORIGIN")` |

Which origins a ceremony is accepted from is the strategy's own policy,
decided from configuration alone. The rules are `ash_authentication`'s and
are spelled out in its WebAuthn guide, under "Relying party and origin"
(see also `AshAuthentication.Strategy.WebAuthn.Origin`); in short:

- **`:webauthn_origin` unset** — missing from the config, or `nil` (the
  installer's default, and the Secrets module returning `:error`): any
  `https` origin whose host is the `rp_id` or a subdomain of it is
  accepted, on any port, plus `http://localhost` on any port when the
  `rp_id` is `"localhost"`. That is exactly the set of origins a browser
  lets use that RP ID in the first place. Development on whatever port
  Phoenix is on needs no configuration, and neither does a deployment
  behind a proxy or across several subdomains.
- **`:webauthn_origin` set**: an exact allowlist, port included — one
  origin or a list. Set it only when ceremonies should be narrowed to
  specific hosts or ports. With `"https://example.com"` a ceremony from
  `https://app.example.com` or `https://example.com:8443` is refused.

Set it per environment like any other config, as a string or a list:

```elixir
# config/dev.exs, config/test.exs: leave :webauthn_origin out.
config :my_app, webauthn_rp_id: "localhost", webauthn_rp_name: "My App"

# config/prod.exs, when the allowlist is static:
config :my_app,
  webauthn_origin: ["https://app.example.com", "https://admin.example.com"]

# config/runtime.exs (what the installer seeds): one origin from the
# environment, or none at all.
config :my_app, webauthn_origin: System.get_env("WEBAUTHN_ORIGIN")
```

What is Phoenix's to get right:

- **The request plays no part.** The request that minted the challenge is
  not consulted: behind a TLS-terminating proxy or load balancer it says
  `http://10.0.0.5:4000` while the browser truthfully signs
  `https://app.example.com` into the ceremony, so a check built on the
  request would reject every ceremony. Nothing in `ash_authentication_phoenix`
  derives an origin from the socket or the conn, and no `Plug.RewriteOn` is
  needed for WebAuthn's sake.
- **LiveView must accept the same origins.** The ceremony runs over the
  LiveView socket, and Phoenix checks the WebSocket's `Origin` header
  against the endpoint's `url` (`check_origin`). Every origin WebAuthn
  accepts must pass that check too: behind a proxy, a tunnel (`ngrok`,
  Cloudflare Tunnel, …) or on several subdomains, set the endpoint's `url`
  to the public host, or list the public origins in `check_origin`.
  Otherwise the page loads but the LiveView never connects, and no
  ceremony starts.

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

Deletion of the last credential is prevented to avoid locking users out of their accounts. All credential operations route through `AshAuthentication.Strategy.WebAuthn.Actions`, so policies, hooks, and validations defined on the credential resource are honored. Credential fields are read through the strategy's accessors, so a credential resource that renames them, or uses a primary key other than `:id`, works unchanged.

### Who may add a passkey

A passkey is a lasting way into the account, so the strategy decides who
may add one, and the component follows:

- `add_credential_enabled? false` removes the add affordance altogether.
- `add_credential_max_authentication_age` (e.g. `{5, :minutes}`) requires
  the user to have authenticated within that window. The component checks
  this *before* the browser prompt; when the session is too old it sends
  the user to re-authenticate — to the second-factor verify page when they
  already hold a passkey, to the sign-in page otherwise — and does the same
  if the window lapses mid-ceremony. The destination is the
  `reauthentication_path` override. What counts as authenticating is the
  actor's metadata, which `AshAuthentication.Phoenix.LiveSession` restores
  from the session: the sign-in token's issue time, or a second-factor
  verification (`webauthn_verified_at`, `totp_verified_at`). Pass
  `authenticated_at` to the component if your application knows better.

Set `add_credential_max_authentication_age`. Without it any authenticated
session, however old, can enrol a passkey of its own.

## Cross-device sign-in (QR / hybrid)

A passkey stored on a phone can be used to sign in on a laptop that has no authenticator of its own. The browser shows a QR code, the phone scans it, and the ceremony completes over Bluetooth proximity plus a relay — the phone never needs a route to your application, so this works on `localhost` in development.

None of that is yours to implement. It is hybrid transport, handled entirely by the browser and the phone's operating system, and the assertion it produces is indistinguishable from one made by a USB security key. The server's part is to ask for it, and the installer does that for you:

```bash
mix ash_authentication_phoenix.add_strategy webauthn --cross-device
```

`--cross-device` is `ash_authentication`'s installer flag, forwarded by this one. It writes three options into the strategy, which you can also set by hand:

```elixir
webauthn :webauthn do
  credential_resource MyApp.Accounts.WebAuthnCredential
  hints [:hybrid, :security_key]
  timeout 180_000
  allow_hint_override? true
end
```

- `hints` orders the kinds of authenticator the browser should lead with: `:hybrid` is the "use your phone or tablet" option, `:security_key` a removable USB/NFC key, `:client_device` the authenticator built into this machine. The components carry it into every ceremony — sign-in, registration, adding a passkey, and second-factor verify — so a machine with no authenticator can enrol a phone passkey and then use it.
- `timeout` must be raised. The default 60 seconds cannot fit a QR scan, a Bluetooth handshake and a prompt on the second device, and the ceremony expires mid-scan; `ash_authentication` warns at compile time if you offer `:hybrid` with less than 120 seconds. The components wait exactly as long as the strategy says, on every page they are embedded in.
- `allow_hint_override? true` lets the client ask for one kind of authenticator per ceremony, which is what the next paragraph needs.

### The "Use a phone or tablet" button

When the strategy offers `:hybrid`, or allows the hint override, every ceremony component renders a second button, "Use a phone or tablet", next to its main one — on the sign-in and registration forms, on the add-a-passkey form of `ManageCredentials`, and on the second-factor verify page. It requests the ceremony with `hints: [:hybrid]`, so a browser that honours hints opens straight on the QR code instead of its picker. The request is honoured only when `allow_hint_override?` is on; otherwise the configured hints stand, exactly as the strategy's own challenge endpoints treat a `?hints=hybrid` parameter. The button is never shown under `authenticator_attachment :platform`, which rules a phone out.

Its text and class are overridable: `cross_device_button_text` and `cross_device_button_class` on `AshAuthentication.Phoenix.Components.WebAuthn.Input` for the forms, and the same two keys on `AshAuthentication.Phoenix.Components.WebAuthn.Verify2faForm`. The predicate behind the button is `AshAuthentication.Phoenix.WebAuthn.cross_device?/1`, should you render your own.

Chrome 128+ honours `hints`. Other browsers ignore members they don't recognise and fall back to their own picker, which already offers the phone — no feature detection is needed. For what happens on the wire, Bluetooth and all, see "Cross-device sign-in" in the [AshAuthentication WebAuthn guide](https://hexdocs.pm/ash_authentication/webauthn.html).

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
- **Ceremonies verify locally but fail behind a proxy, or on another port or subdomain** — Check `:webauthn_origin`. Unset, the strategy accepts any `https` origin on the `rp_id` (and `http://localhost` on any port for `"localhost"`); set, the browser's exact origin, port included, must be in the list. Nothing is read from the request, so `Plug.RewriteOn` makes no difference here.
- **"Sign in with Passkey" shows no passkey for a registered security key** — The credential is non-discoverable: it was created with `resident_key` other than `:required`, or on a key whose storage for discoverable credentials was full. Sign-in never lists credentials, so only discoverable ones can answer; such a key can still serve as a second factor.
- **WebAuthn prompt never appears in dev** — You're serving over plain HTTP from a hostname other than `localhost` / `127.0.0.1`. Either use `localhost` or run dev over HTTPS.
- **Credentials missing after deploy** — The `rp_id` likely changed. Credentials are bound to the exact `rp_id` they were registered under.
- **Hooks not firing** — Verify all three hooks are registered in `app.js` and that the LiveView is using them. Check the browser console for hook initialization errors.
- **"Failed to register new key"** — Check that the `credential_resource` exists and that the `:create` action accepts the credential attributes.
