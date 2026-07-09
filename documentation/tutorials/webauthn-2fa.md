<!--
SPDX-FileCopyrightText: 2026 Alembic Pty Ltd

SPDX-License-Identifier: MIT
-->

# Passkeys as Second Factor (2FA)

This guide explains how to use a WebAuthn passkey as a *second* authentication
factor — i.e. as a step the user performs *after* signing in with their primary
credential (typically a password). For setting WebAuthn up as the *primary*
sign-in method, see the [WebAuthn / Passkey Authentication](webauthn.md) guide
instead.

## Overview

Two-factor authentication (2FA) requires two different forms of verification:

1. **Something you know** — a password, magic link, etc.
2. **Something you have** — a hardware security key, Touch ID / Face ID, or a
   passkey on the user's phone.

With passkey-based 2FA enabled, users sign in with their primary credential
first, then complete a WebAuthn ceremony. The result of the ceremony is
recorded against the user's authentication token as a `webauthn_verified_at`
claim, which protected routes can require.

> ### Why not just use passkeys as primary? {: .info}
>
> Passkeys-as-primary is great when you want a passwordless experience. 2FA
> mode is the right choice when:
>
> - You want to keep an existing password flow but add a hardware-bound second
>   step (defence in depth).
> - You're rolling out passkeys gradually — users without a registered
>   passkey can still sign in normally; only protected routes require the
>   second factor.
> - Compliance or threat models require multiple independent factors.
>
> The two modes can also coexist: a user can use a passkey to sign in
> *primarily*, and a different strategy (e.g. TOTP) as the second factor. See
> the [TOTP 2FA guide](totp-2fa.md) for that variant.

## Prerequisites

Ensure you have:

1. A primary authentication strategy configured (password, magic link, etc.).
2. The WebAuthn strategy configured **in 2FA mode** (see below).
3. Tokens enabled — 2FA verification depends on the token-claim plumbing.

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

      webauthn do
        credential_resource MyApp.Accounts.WebAuthnCredential
        rp_id MyApp.Secrets
        rp_name MyApp.Secrets
        origin MyApp.Secrets
        identity_field :email

        # 2FA mode: the strategy doesn't register or sign users in directly,
        # it only verifies an assertion against an already-authenticated user.
        registration_enabled? false
        sign_in_enabled?      false
        verify_enabled?       true
      end
    end
  end
end
```

## Installation

The fastest path is the installer:

```bash
mix ash_authentication_phoenix.add_strategy webauthn --mode 2fa
```

`--mode 2fa` is what changes the generated configuration:

| Mode (default `primary`) | `registration_enabled?` | `sign_in_enabled?` | `verify_enabled?` |
| --- | --- | --- | --- |
| `primary`                | `true`                  | `true`             | `true`            |
| `2fa`                    | `false`                 | `false`            | `true`            |

In 2FA mode the installer also:

- Generates the credential resource (same as primary mode).
- Registers `webauthn_2fa_route` and `webauthn_setup_route` macros in your
  router (see below).
- Adds `success/4` clauses to your `AuthController` that intercept primary
  sign-ins and route the user through the verify page.

## Built-in WebAuthn 2FA routes

`ash_authentication_phoenix` provides two router macros that mount the LiveView
pages used by the 2FA flow. They're analogous to the TOTP equivalents:

### `webauthn_2fa_route`

The verification page. Mounted by default at `/webauthn-verify`. Two flows:

- **Token flow** (`/webauthn-verify/:token`) — used after a primary sign-in. The
  `:token` is a short-lived JWT containing the user's subject; the page
  performs the WebAuthn ceremony, exchanges the asserted token for a session
  on success.
- **Step-up flow** (`/webauthn-verify`) — used by an already-signed-in user
  re-asserting their second factor for a sensitive action.

### `webauthn_setup_route`

The setup page. Mounted by default at `/webauthn-setup`. An authenticated user
registers a new passkey to their account here. Wraps the existing
`AshAuthentication.Phoenix.Components.WebAuthn.ManageCredentials` component, so
the same screen also lets users see, label, and revoke existing credentials.

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
    plug :set_scope, scope: MyApp.Accounts.Scope, default_scope?: true
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    auth_routes AuthController, MyApp.Accounts.User, path: "/auth"

    sign_in_route auth_routes_prefix: "/auth"

    webauthn_2fa_route   MyApp.Accounts.User, :webauthn, auth_routes_prefix: "/auth"
    webauthn_setup_route MyApp.Accounts.User, :webauthn, auth_routes_prefix: "/auth"
  end
end
```

> ### Browser pipeline {: .info}
>
> `plug :load_from_session` and `plug :set_scope, ...` are required. The
> 2FA verify ceremony reads the user from `Ash.PlugHelpers.get_actor/1`, which
> relies on those two plugs having run (`set_scope` is a superset of `set_actor`;
> `plug :set_actor, :user` works too if you aren't using scopes).

Options for both macros (matching the TOTP versions):

- `path` — override the default mount path.
- `live_view` — supply a custom LiveView module.
- `auth_routes_prefix` — **required**, makes the form post URLs work.
- `overrides` — list of override modules for UI customisation.

## How verification is recorded — the `webauthn_verified_at` claim

When the user completes the WebAuthn ceremony, the strategy's verify action
returns a fresh JWT for the user with one extra claim:

```json
{
  "sub": "user?id=...",
  "purpose": "sign_in",
  "webauthn_verified_at": "2026-05-07T12:34:56Z"
}
```

That claim is the source of truth for "this session has been verified by a
passkey". `store_in_session` also stamps the matching
`:webauthn_verified_at` value onto the user's metadata, which survives
`load_from_session` round-trips for browser flows. The JWT claim covers
headless / `Authorization: Bearer …` flows. Both forms get preserved
through the `sign_in_with_token` exchange.

> ### What's deliberately *not* in the claim {: .warning}
>
> Only the timestamp is recorded. The credential ID, authenticator make /
> model, and any other device-fingerprinting information stay on the server.
> A leaked token cannot be used to identify the user's specific authenticator.

## Requiring WebAuthn for protected routes

### `Plug.RequireWebAuthn`

Use this for controller-based routes:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :require_webauthn do
    plug AshAuthentication.Phoenix.Plug.RequireWebAuthn,
      resource: MyApp.Accounts.User,
      on_unverified: :redirect_to_verify,
      on_unconfigured: :redirect_to_setup
  end

  scope "/", MyAppWeb do
    pipe_through [:browser, :require_webauthn]

    get "/admin", AdminController, :index
  end
end
```

`RequireWebAuthn` reads the user's authentication token claims via
`AshAuthentication.Plug.Helpers.retrieve_from_session/2` and decides what to
do:

| Situation | Action |
| --- | --- |
| No current user | Pass through (let your auth pipeline handle it) |
| User has no registered passkeys (`webauthn_configured?` is `false`) | `on_unconfigured` (default `:redirect_to_setup`) |
| User has passkeys but token has no `webauthn_verified_at` claim | `on_unverified` (default `:redirect_to_verify`) |
| Token has `webauthn_verified_at` and freshness check passes | Pass through |

#### Plug options

| Option | Description | Default |
| --- | --- | --- |
| `resource` | The user resource module | Required |
| `strategy` | WebAuthn strategy name | First WebAuthn strategy on the resource |
| `on_unconfigured` | `:halt` \| `:redirect_to_setup` \| `{:redirect, path}` | `:redirect_to_setup` |
| `on_unverified` | `:halt` \| `:redirect_to_verify` \| `{:redirect, path}` | `:redirect_to_verify` |
| `setup_path` | Path to redirect to when unconfigured | `"/webauthn-setup"` |
| `verify_path` | Path to redirect to when unverified | `"/webauthn-verify"` |
| `max_age` | Maximum age of `webauthn_verified_at` (seconds) before requiring re-verification | `nil` (no expiry) |
| `current_user_assign` | Assign holding the user | `:current_user` |

### `LiveSession.RequireWebAuthn`

The LiveView equivalent — wire it into `ash_authentication_live_session`'s
`on_mount`:

```elixir
scope "/", MyAppWeb do
  pipe_through :browser

  ash_authentication_live_session :admin,
    on_mount: [
      {AshAuthentication.Phoenix.LiveSession.RequireWebAuthn, :require_webauthn}
    ] do
    live "/admin/dashboard", AdminLive
  end
end
```

Pass options as a tuple to tune behaviour:

```elixir
on_mount: [
  {AshAuthentication.Phoenix.LiveSession.RequireWebAuthn,
    {:require_webauthn, max_age: 300, verify_path: "/step-up"}}
]
```

## Auth controller integration

When using the `--mode 2fa` installer, this clause gets prepended to your
`AuthController`:

```elixir
defmodule MyAppWeb.AuthController do
  use MyAppWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, {_, phase} = _activity, user, token)
      when phase in [:sign_in, :sign_in_with_token] do
    return_to = get_session(conn, :return_to) || ~p"/"

    cond do
      AshAuthentication.Phoenix.WebAuthnHelpers.webauthn_verified?(user) ->
        conn
        |> store_in_session(user)
        |> set_live_socket_id(token)
        |> assign(:current_user, user)
        |> redirect(to: return_to)

      AshAuthentication.Phoenix.WebAuthnHelpers.webauthn_configured?(user) ->
        conn
        |> store_in_session(user)
        |> set_live_socket_id(token)
        |> assign(:current_user, user)
        |> put_session(:return_to, return_to)
        |> redirect(to: ~p"/webauthn-verify/#{token}")

      true ->
        conn
        |> store_in_session(user)
        |> set_live_socket_id(token)
        |> assign(:current_user, user)
        |> put_session(:return_to, return_to)
        |> redirect(to: ~p"/webauthn-setup")
    end
  end

  # Default catch-all for other auth activities (registration, sign-out, …).
  def success(conn, activity, user, token), do: # ...
end
```

The single clause matches both the *initial* primary sign-in and the
*follow-up* `sign_in_with_token` that the WebAuthn LiveView triggers after a
successful ceremony, distinguished by the user's
`:webauthn_verified_at` metadata:

1. **Primary sign-in succeeds, no `:webauthn_verified_at` yet** — fall
   through to the second `cond` arm and route to `/webauthn-verify` (or
   `/webauthn-setup` if the user has no passkeys yet).
2. **WebAuthn ceremony completes** — the strategy returns a fresh user
   with `:webauthn_verified_at` set; the LiveView trigger-submits the token
   to `sign_in_with_token`; the first arm matches; the user is redirected
   to their original destination.
3. **Subsequent requests** — `RequireWebAuthn` reads the metadata (browser
   flows) or the JWT claim (bearer flows) and lets the user through until
   the session expires or the optional `:max_age` window elapses.

## `WebAuthnHelpers`

```elixir
alias AshAuthentication.Phoenix.WebAuthnHelpers

# Does the user have at least one registered passkey?
WebAuthnHelpers.webauthn_configured?(user)
#=> true

# Does the *current request* have a valid webauthn_verified_at claim?
WebAuthnHelpers.webauthn_verified?(conn_or_socket)
#=> true

# Same as above, with a freshness window in seconds.
WebAuthnHelpers.webauthn_verified?(conn_or_socket, max_age: 300)
#=> false   # last verification was 6 minutes ago

# Get the WebAuthn strategy on a resource.
{:ok, strategy} = WebAuthnHelpers.get_webauthn_strategy(MyApp.Accounts.User)
```

## Setup page

The installer mounts a setup page at `/webauthn-setup` that wraps the
existing `ManageCredentials` component, so users can register, label, and
revoke passkeys from one screen.

In the post-primary-sign-in flow, the AuthController stashes the original
destination in the session as `:return_to` before redirecting to setup.
`WebAuthnSetupLive` reads it and threads it into `ManageCredentials` as
`continue_path`; once the user has registered at least one credential, a
"Continue" button appears that takes them on to that destination.

If you want to render the setup form yourself (e.g. inside a settings page):

```elixir
defmodule MyAppWeb.SecuritySettingsLive do
  use MyAppWeb, :live_view
  alias AshAuthentication.Phoenix.Components.WebAuthn.ManageCredentials

  def mount(_params, _session, socket) do
    {:ok, strategy} =
      AshAuthentication.Info.strategy(MyApp.Accounts.User, :webauthn)

    {:ok, assign(socket, strategy: strategy)}
  end

  def render(assigns) do
    ~H"""
    <h1>Security</h1>

    <.live_component
      module={ManageCredentials}
      id="webauthn-credentials"
      strategy={@strategy}
      current_user={@current_user}
    />
    """
  end
end
```

Pass `continue_path={"/some/path"}` to the live component to surface the
"Continue" affordance in your own setup screens too.

## Step-up authentication

The same verify page handles "I'm signed in but I need to re-prove this is
me before doing X". Send the user to `/webauthn-verify` (no `:token` —
that's the trigger for step-up mode) and they get a one-shot ceremony. On
success the JWT is re-issued with a fresh `:webauthn_verified_at` and
`RequireWebAuthn`'s `:max_age` check passes again.

```elixir
defmodule MyAppWeb.AdminLive do
  use MyAppWeb, :live_view
  alias AshAuthentication.Phoenix.WebAuthnHelpers

  def handle_event("delete_user", %{"id" => id}, socket) do
    if WebAuthnHelpers.webauthn_verified?(socket, max_age: 300) do
      # Recently verified — proceed.
      {:noreply, do_delete(socket, id)}
    else
      # Stash where to come back to, then redirect.
      {:noreply,
       socket
       |> put_flash(:info, "Please re-verify with your passkey to continue.")
       |> push_navigate(to: "/webauthn-verify")}
    end
  end
end
```

`RequireWebAuthn` writes the original destination into `:return_to` for
you when it does the redirect; for hand-rolled redirects like the example
above you'll need to thread that yourself if you want to land back on the
original page. (We're tracking a nicer step-up affordance —
`AshAuthentication.Phoenix.WebAuthnHelpers.step_up/2` — alongside the
multi-factor chooser in
[#740](https://github.com/team-alembic/ash_authentication_phoenix/issues/740).)

## Combining with TOTP

Mounting both `webauthn_2fa_route` and `totp_2fa_route` on the same resource
is supported, but the installed `AuthController.success/4` clauses currently
favour whichever strategy was added last. A user-facing chooser ("verify
with passkey or TOTP code?") is being tracked in
[#740](https://github.com/team-alembic/ash_authentication_phoenix/issues/740);
until it lands, pick one as the canonical path or hand-write a
`success/4` clause that branches on user preference.

See the [TOTP as 2FA guide](totp-2fa.md) for the parallel TOTP plumbing.

## Recovery

When a user loses access to their passkey, the
[recovery code add-on](recovery-codes.md) gives them a one-time fallback.
Generate recovery codes during onboarding and surface them in the security
settings page.

> ### Heads up — recovery currently bypasses, not replaces, the WebAuthn check {: .warning}
>
> `RequireWebAuthn` only honours `:webauthn_verified_at`. A successful
> recovery code completes primary sign-in but doesn't satisfy the WebAuthn
> requirement on its own — so recovery should usually be paired with a
> setup-or-disable flow that lets the user register a fresh passkey before
> they hit a `RequireWebAuthn`-protected route. Cross-strategy verification
> ("recovery counts as second factor") is being tracked alongside the
> [multi-factor chooser](https://github.com/team-alembic/ash_authentication_phoenix/issues/740).

## Headless / API clients

Because the verification status lives in the JWT (not just session cookies),
non-browser clients can use the same flow:

1. Primary auth → token A (no `webauthn_verified_at`).
2. Client posts assertion to `POST /auth/<subject>/webauthn/verify` with
   `Authorization: Bearer <token A>`.
3. Server returns token B containing `webauthn_verified_at`.
4. Client uses token B for protected calls.

The browser flow is just a UI on top of these endpoints.

## Security notes

### Verified versus configured

It's worth being explicit about the model:

- `webauthn_configured?` — does the user have at least one passkey registered?
- `webauthn_verified?` — has the *current request's* token been issued by a
  successful WebAuthn ceremony?

Protected routes should require **verified**, not just configured. The
default `RequireWebAuthn` plug enforces this. (Compare with the TOTP
helpers, where the equivalent `RequireTotp` only checks *configured* — see
the [TOTP 2FA guide](totp-2fa.md) for the rationale.)

### Freshness

For high-impact actions (deleting an account, transferring funds, changing
passwords), set a short `max_age` on `RequireWebAuthn` so the user has to
touch their passkey again, even within an otherwise-valid session.

### Replay

The verify endpoint validates a Wax challenge that was issued by the same
server within the last 60 seconds (configurable via
`AshAuthentication.Strategy.WebAuthn`'s `:timeout` option). Replaying an old
assertion against a stale challenge is rejected.

### Credential-to-user binding

The verify action filters credential lookups by `user_id == actor.id`, so a
ceremony presented with a credential belonging to a *different* user is
rejected even if the signature would otherwise verify. This is enforced
server-side and isn't user-configurable.

## Next steps

- [WebAuthn / Passkey Authentication](webauthn.md) — primary-mode setup.
- [TOTP as 2FA](totp-2fa.md) — the TOTP analogue of this guide.
- [Recovery Codes](recovery-codes.md) — fallback factor for when the user
  loses access to their passkey.
- [LiveView Integration](liveview.md) — broader LiveView auth patterns.
- [UI Overrides](ui-overrides.md) — customising the verify and setup
  components.
