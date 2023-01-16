# AshAuthentication.Phoenix

![Logo](https://github.com/ash-project/ash/blob/main/logos/ash-auth-logo.svg?raw=true)
![Elixir CI](https://github.com/team-alembic/ash_authentication_phoenix/workflows/Elixir%20Library/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_authentication_phoenix.svg)](https://hex.pm/packages/ash_authentication_phoenix)

The `ash_authentication_phoenix` package extends
[`ash_authentication`](https://github.com/team-alembic/ash_authentication) by
adding router helpers, plugs and behaviours that makes adding authentication to
an existing Ash-based Phoenix application dead easy.

## Warning

This is **beta** software.  Please don't use it without talking to us!

## Installation

The package can be installed by adding `ash_authentication_phoenix` to your list
of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_authentication_phoenix, "~> 1.4.2"}
  ]
end
```

If you wish to use our default [Tailwind](https://tailwindcss.com/)-based
components, you will need to add the path to `ash_authentication_phoenix`'s
components in your `assets/tailwind.config.js`:

```javascript
module.exports = {
  content: [
    // Other paths.
    "../deps/ash_authentication_phoenix/**/*.ex"
  ]
}
```

## Usage

This package assumes that you have [Phoenix](https://phoenixframework.org/),
[Ash](https://ash-hq.org/) and
[AshAuthentication](https://github.com/team-alembic/ash_authentication)
installed and configured.  See their individual documentation for details.

This package is designed so that you can choose the level of customisation
required.  At the easiest level of configuration, you can just add the routes
into your router:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    # ...
    plug(:load_from_session)
  end

  scope "/" do
    pipe_through :browser
    sign_in_route
    sign_out_route MyAppWeb.AuthController
    auth_routes_for MyApp.Accounts.User, to: MyAppWeb.AuthController
  end
end
```

This will give you a generic sign-in/registration page and store the
authenticated user in the Phoenix session.

### Customisation

There are several methods of customisation available depending on the level of
control you would like:

  1. Use the [generic sign-in liveview](https://hexdocs.pm/ash_authentication_phoenix/AshAuthentication.Phoenix.SignInLive.html).
  2. Apply [overrides](https://hexdocs.pm/ash_authentication_phoenix/AshAuthentication.Phoenix.Overrides.html)
     to set your own CSS classes for all components.
  3. Build your own sign-in pages using the pre-defined components.
  4. Build your own sign-in pages using the generated `auth` routes.

## Documentation

Documentation for the latest release will be [available on
hexdocs](https://hexdocs.pm/ash_authentication_phoenix) and for the [`main`
branch](https://team-alembic.github.io/ash_authentication_phoenix).

## Contributing

  * To contribute updates, fixes or new features please fork and open a pull-request against `main`.
  * Please use [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/) - this allows us to dynamically generate the changelog.
  * Feel free to ask any questions on out [GitHub discussions page](https://github.com/team-alembic/ash_authentication_phoenix/discussions).

## Licence

MIT
