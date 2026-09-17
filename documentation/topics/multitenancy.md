<!--
SPDX-FileCopyrightText: 2026 Alembic Pty Ltd

SPDX-License-Identifier: MIT
-->

# Multitenancy

AshAuthenticationPhoenix carries the tenant. It does not discover it.

Once a tenant is set on the connection, every part of the sign-in flow picks it
up: the strategy plugs pass it to your actions, `load_from_session/2` uses it to
load the current user, the sign-in LiveViews receive it as `current_tenant`, and
`set_scope` puts it on the scope struct. None of that happens until something in
your pipeline says what the tenant is, and that part is yours to write — the
tenant might come from a subdomain, a path segment, a request header, or a
property of the user themselves, and only your application knows which.

This guide covers where to set it and what changes for each of those sources.

## Setting the tenant

The tenant is set by a plug you write yourself.
[`Ash.PlugHelpers.set_tenant/2`](https://hexdocs.pm/ash/Ash.PlugHelpers.html#set_tenant/2)
takes the tenant as its second argument, so it is a function you call, not a
plug you install. Your plug works out the tenant for the request, then calls it.

This guide calls that plug `set_tenant` and defines it as a private function in
your router. Every example under [Choosing a source](#choosing-a-source) is a
body for it. Add it to your browser pipeline, before `load_from_session` and
before any request reaches `auth_routes`, `sign_in_route` or `sign_out_route`:

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, {MyAppWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers

  plug :set_tenant
  plug :load_from_session
  plug :set_scope, scope: MyApp.Accounts.Scope, default_scope?: true
end
```

Only `:set_tenant` is yours. `use AshAuthentication.Phoenix.Router` imports
`load_from_session/2` and `set_scope/2`, so those two need nothing from you.

`set_tenant/2` stores the tenant under `conn.private.ash`, so it does not
collide with your assigns, and
[`Ash.PlugHelpers.get_tenant/1`](https://hexdocs.pm/ash/Ash.PlugHelpers.html#get_tenant/1)
reads it back. Everything downstream reads it through `get_tenant/1` rather
than looking at the connection itself, so the source stays entirely up to you.

Do the same in your `:api` and `:graphql` pipelines, ahead of
`load_from_bearer`.

## Validating the tenant

`set_tenant/2` records a value. It does not check that the value names a tenant
you have, and nothing downstream checks it either. Every source in the next
section is chosen by the client, so treat the value as untrusted input.

An unknown tenant does not reach another tenant's data. Under `strategy
:attribute` it becomes a filter value, so reads come back empty. Writes are
less tidy: the attribute is set to the unknown value, which lands you a cast
error, a foreign key error, or a row belonging to a tenant that does not exist
— and registration is a write that anonymous visitors can reach. Under
`strategy :context` with AshPostgres the value becomes a schema name, which
Ecto quotes as an identifier, so an unknown tenant is a database error rather
than an injection.

So validate for the sake of the behaviour you want, not for isolation. Look the
tenant up in your plug and halt with a 404 when it does not exist. That is
better than an empty page, a 500, or a stray row. The lookup is usually already
there, because resolving a subdomain or a slug to the value your resources use
as the tenant is the same query.

The check that matters more is a different one: may *this* user use *this*
tenant? Confirming that a subdomain names a real organisation does not answer
that. Where it gets enforced depends on the user resource:

* A multitenant user resource enforces it itself. The identity lookups and the
  read behind `load_from_session/2` both run against the tenant on the
  connection, and a stored token carries a `tenant` claim which must match. A
  user belonging to another tenant does not load.
* A user resource that is readable without a tenant enforces nothing. The user
  loads, and the tenant stays whatever the request asked for. Enforce the
  pairing yourself, with policies on the resources you read, or by comparing
  the tenant against the organisation the user belongs to.

## Choosing a source

### Subdomain

The host is available on every request, including the `POST` to the auth routes,
which makes this the least fiddly option:

```elixir
defp set_tenant(conn, _opts) do
  case String.split(conn.host, ".") do
    [subdomain, _, _] -> Ash.PlugHelpers.set_tenant(conn, subdomain)
    _ -> conn
  end
end
```

Resolve the subdomain to whatever your resources actually use as a tenant — an
organisation ID, a schema name — rather than passing the raw string through, if
the two differ.

### Request header

For APIs, where the host is usually the same for every tenant, ask the client to
name the tenant on each request:

```elixir
defp set_tenant(conn, _opts) do
  case Plug.Conn.get_req_header(conn, "x-tenant") do
    [tenant] -> Ash.PlugHelpers.set_tenant(conn, tenant)
    _ -> conn
  end
end
```

`x-tenant` is a name this example invented. Neither Ash nor this package knows
it, and nothing sends it for you. Choose whatever name suits you, document it
for the people who call your API, and have their clients send it on every
request. A request without the header has no tenant.

### Path segment

Path segments take the most work, because not every route macro can live under
one.

Two rules decide the layout. First, `auth_routes` mounts its strategy router
with Phoenix's `forward`, and Phoenix refuses to forward from a path containing
a dynamic segment:

```
** (ArgumentError) dynamic segment "/org/:org/auth" not allowed when forwarding.
Use a static path instead
```

Second, any option whose value is turned into a link or a form action —
`auth_routes_prefix`, `register_path`, `reset_path` — is expanded against the
enclosing scope at compile time. Inside `scope "/org/:org"` that produces a
literal `/org/:org/register`, which is not a URL anybody can follow.

So `auth_routes` and `sign_out_route` stay at a static path, the LiveView routes
move into the tenant scope with `auth_routes_prefix: {:unscoped, "/auth"}`, and
`register_path` and `reset_path` come off the `sign_in_route` — without them the
sign-in page switches to its registration and reset forms with JavaScript rather
than navigation, so no link needs generating.

Starting from the block the installer generates:

```elixir
scope "/", MyAppWeb do
  pipe_through :browser

  auth_routes AuthController, MyApp.Accounts.User, path: "/auth"
  sign_out_route AuthController, "/sign-out"

  sign_in_route register_path: "/register",
                reset_path: "/reset",
                auth_routes_prefix: "/auth",
                on_mount: [{MyAppWeb.LiveUserAuth, :live_no_user}]

  reset_route auth_routes_prefix: "/auth"

  confirm_route MyApp.Accounts.User, :confirm_new_user, auth_routes_prefix: "/auth"

  magic_sign_in_route MyApp.Accounts.User, :magic_link, auth_routes_prefix: "/auth"
end
```

split it in two:

```elixir
scope "/", MyAppWeb do
  pipe_through :browser

  auth_routes AuthController, MyApp.Accounts.User, path: "/auth"
  sign_out_route AuthController, "/sign-out"
end

scope "/org/:org", MyAppWeb do
  pipe_through :browser

  sign_in_route auth_routes_prefix: {:unscoped, "/auth"},
                on_mount: [{MyAppWeb.LiveUserAuth, :live_no_user}]

  reset_route auth_routes_prefix: {:unscoped, "/auth"}

  confirm_route MyApp.Accounts.User, :confirm_new_user,
    auth_routes_prefix: {:unscoped, "/auth"}

  magic_sign_in_route MyApp.Accounts.User, :magic_link,
    auth_routes_prefix: {:unscoped, "/auth"}
end
```

Keep the `overrides:` options the installer generated on each of these — they
are omitted above only to keep the example readable.

The sign-in LiveView now renders under `/org/acme/sign-in`, where `:org` is in
the path params, but it submits to `/auth/user/password/sign_in`, where it is
not. Your plug therefore needs to remember the tenant across that hop. The
session is the natural place:

```elixir
defp set_tenant(conn, _opts) do
  case conn.path_params["org"] do
    nil ->
      Ash.PlugHelpers.set_tenant(conn, Plug.Conn.get_session(conn, "tenant"))

    org ->
      conn
      |> Plug.Conn.put_session("tenant", org)
      |> Ash.PlugHelpers.set_tenant(org)
  end
end
```

Phoenix merges path params into the connection before running the pipeline, so
`conn.path_params` is populated by the time this plug sees it. `fetch_session`
must still come first.

One consequence worth planning for: the URLs in your magic link and password
reset emails are generated by your senders, not by this package. If your sign-in
routes are tenant-scoped, those senders need to build tenant-scoped URLs too.

## When the tenant belongs to the user

Sometimes there is nothing in the request to read. The tenant is a property of
the user — the organisation they belong to — and you only find out which one it
is by loading them, which is the very thing that needs the tenant.

There is no way around that ordering. What you can do is stop requiring the
tenant for the sign-in itself:

* Keep the user resource readable without a tenant. Where the identity is
  globally unique (an email address, say), the user record can be looked up
  globally and the tenancy enforced on everything the user then does, through
  policies and through the tenant on their scope.
* Set the tenant once you know it. `success/4` in your generated
  `AuthController` runs with the authenticated user in hand, so it can write the
  tenant to the session before redirecting:

  ```elixir
  def success(conn, _activity, user, token) do
    conn
    |> put_session("tenant", user.organisation_id)
    |> store_in_session(user)
    |> set_live_socket_id(token)
    |> assign(:current_user, user)
    |> redirect(to: ~p"/")
  end
  ```

  A plug that reads `get_session(conn, "tenant")` then has a tenant on every
  subsequent request, exactly as in the path-segment case above.

If the user resource is itself multitenant and its tokens are stored, be careful
that the two ends agree. Tokens minted for a multitenant resource carry a
`tenant` claim, and verification checks that claim against the tenant on the
current request. A token minted with no tenant will not verify on a request that
has one — the user simply fails to load from the session, with no error. Make
sure the tenant is the same at sign-in as it is afterwards.

## Reaching LiveView

This part is already wired up; you do not need to reimplement it.

Both `ash_authentication_live_session` and the route macros in
`AshAuthentication.Phoenix.Router` build their live session's session map with
`Ash.PlugHelpers.get_tenant(conn)` under the `"tenant"` key. On mount,
`AshAuthentication.Phoenix.LiveSession` reads it back and assigns it as
`current_tenant`, and uses it as the `tenant:` option when loading the current
user from the session.

```elixir
def mount(_params, _session, socket) do
  posts = MyApp.Blog.list_posts!(tenant: socket.assigns.current_tenant)
  {:ok, assign(socket, :posts, posts)}
end
```

The sign-in, reset, confirmation, magic link, TOTP, recovery code and WebAuthn
LiveViews all do the same, and pass `current_tenant` down into the forms they
render, so the actions those forms call run against the right tenant.

If you assign `:current_tenant` yourself in an earlier `on_mount` hook, that
value wins over the one from the session.

## Scopes

The `Scope` struct the installer generates already carries the tenant:

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

`set_scope` populates `:tenant` from `Ash.PlugHelpers.get_tenant/1`, and the
LiveView equivalent populates it from `session["tenant"]`. So once the
connection has a tenant, passing `scope:` to an action carries both the actor
and the tenant, and there is nothing further to configure:

```elixir
MyApp.Blog.list_posts!(scope: conn.assigns.current_scope)
```

See [Scopes](scopes.md) for the rest of what the scope does.

## Multitenant user resources and `global?`

A multitenant resource with `global? false` cannot be touched without a tenant.
Reads fail with `Ash.Error.Invalid.TenantRequired`; changesets fail validation
with "requires a tenant to be specified".

Applied to the user resource, that covers every action AshAuthentication runs on
your behalf: the identity lookups during sign-in, registration, confirmation and
password resets, and the read that `load_from_session/2` performs on each
request. All of them use the tenant from the connection, so any request that
reaches them without one fails.

In practice a `global? false` user resource requires a tenant that can be
determined from the request alone — a subdomain or a header — on every route in
the pipeline, including the anonymous ones. Path-segment tenancy only clears
that bar with the session fallback above in place, and never for the first
request of a session; a tenant that is only knowable once the user is loaded
never clears it at all. If you cannot guarantee a tenant that early, set
`global? true` on the user resource and enforce the tenancy through policies
instead.
