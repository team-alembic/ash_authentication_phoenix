<!--
SPDX-FileCopyrightText: 2022 Alembic Pty Ltd

SPDX-License-Identifier: MIT
-->

# Scopes

AshAuthenticationPhoenix can wrap the current actor and tenant in a single
[`Ash.Scope`](https://hexdocs.pm/ash/Ash.Scope.html) struct, so you can pass one
value into your Ash actions rather than threading `actor:` and `tenant:`
separately:

```elixir
# instead of
Ash.read!(query, actor: conn.assigns.current_user, tenant: conn.assigns.current_tenant)

# you can write
Ash.read!(query, scope: conn.assigns.current_user_scope)
```

This mirrors the [`current_scope` concept from `mix phx.gen.auth`](https://hexdocs.pm/phoenix/scopes.html),
while keeping AshAuthentication's support for multiple authenticated resources.

## The scope module

The installer generates a scope struct in your accounts namespace:

```elixir
defmodule MyApp.Accounts.Scope do
  defstruct [:actor, :tenant]

  defimpl Ash.Scope.ToOpts, for: __MODULE__ do
    def get_actor(%{actor: actor}), do: {:ok, actor}
    def get_tenant(%{tenant: tenant}), do: {:ok, tenant}
    def get_context(_scope), do: :error
    def get_tracer(_scope), do: :error
    def get_authorize?(_scope), do: :error
  end
end
```

This is your extension point. As your application grows, add fields such as the
current organisation, permissions, or locale, and expose them through the
`Ash.Scope.ToOpts` callbacks. The struct is keyed on `:actor` (not `:user`) so a
single struct type serves every authenticated resource.

## Scope assigns

Scopes are built from the assigns that `load_from_session/2` and
`load_from_bearer/2` already set. For each authenticated resource, a
`current_<subject_name>_scope` assign is added alongside the existing
`current_<subject_name>`:

| Subject | Actor assign     | Scope assign            |
| ------- | ---------------- | ----------------------- |
| `:user` | `:current_user`  | `:current_user_scope`   |
| `:admin`| `:current_admin` | `:current_admin_scope`  |

One subject can also be nominated as the application's primary, in which case its
scope is additionally assigned to the singular `:current_scope` — the assign
Phoenix-idiomatic code expects.

## In the plug pipeline

The `set_scope` plug builds the scope and sets the Ash actor. It is a superset of
`set_actor` — use it *instead of* `set_actor`, not alongside it:

```elixir
pipeline :browser do
  plug :load_from_session
  plug :set_scope, scope: MyApp.Accounts.Scope, default_scope?: true
end
```

* `:scope` — the scope module to instantiate (required).
* `:subject` — the subject to build the scope for. Defaults to `:user`.
* `:default_scope?` — when `true`, also assigns `:current_scope`. Defaults to
  `false`.

For a non-default subject:

```elixir
plug :set_scope, scope: MyApp.Accounts.Scope, subject: :admin
```

## In LiveView

Pass a `:scope` option to `ash_authentication_live_session` to add
`current_<subject_name>_scope` assigns to the socket, and `:default_scope` to
nominate the subject whose scope is also assigned to `:current_scope`:

```elixir
ash_authentication_live_session :authenticated_routes,
  scope: MyApp.Accounts.Scope,
  default_scope: :user do
  live "/", MyAppWeb.HomeLive
end
```

```elixir
def mount(_params, _session, socket) do
  posts = MyApp.Blog.list_posts!(scope: socket.assigns.current_scope)
  {:ok, assign(socket, :posts, posts)}
end
```

## Anonymous requests

When no subject is signed in, the scope is still built with `actor: nil`. Passing
it to an action clears the actor, exactly as `actor: nil` would — so anonymous
requests get a valid (unauthenticated) scope rather than a missing assign.
