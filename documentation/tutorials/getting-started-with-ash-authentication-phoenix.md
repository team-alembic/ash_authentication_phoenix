# Getting Started Ash Authentication Phoenix

In this step-by-step tutorial we create a new empty `Example` Phoenix application which provides the functionality to register users with their email address and a password. Registered users can sign in and out. Afterwards we will add the functionality to reset the password.

We assumes that you have [Elixir](https://elixir-lang.org) version 1.14.x (check with `elixir -v`) and Phoenix 1.7 (check with `mix phx.new --version`) installed. We also assume that you have a [PostgreSQL](https://www.postgresql.org) database running which we use to persist the user data.

## Green Field

We start with a new Phoenix application and use the `--no-ecto` flag to skip the [Ecto](https://hexdocs.pm/ecto/Ecto.html) setup.

```bash
$ mix phx.new example --no-ecto
$ cd example
```

## Application Dependencies

We need to add the following dependencies:

**mix.exs**

```elixir
defmodule Example.MixProject do
  use Mix.Project
  # ...

    defp deps do
    [
      # ...
      # add these lines -->
      {:ash, "~> 2.5.11"},
      {:ash_authentication, "~> 3.7.3"},
      {:ash_authentication_phoenix, "~> 1.4.7"},
      {:ash_postgres, "~> 1.3.2"},
      {:elixir_sense, github: "elixir-lsp/elixir_sense", only: [:dev, :test]} 
      # <-- add these lines
    ]
  end
  # ...
```

Let's fetch everything:

```bash
$ mix deps.get
```

## Formatter

We can make our life easier and the code more consistent by adding formatters to the project. We will use [Elixir's built-in formatter](https://hexdocs.pm/mix/master/Mix.Tasks.Format.html) for this.

**.formatter.exs**

```elixir
[
  import_deps: [
    :phoenix,
    # add these lines -->
    :ash,
    :ash_authentication_phoenix,
    :ash_postgres
    # <-- add these lines
    ],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}"]
]
```

## Phoenix 1.7 compatibility

For Phoenix 1.7 we need to change `helpers: false` to `helpers: true` in the router section:

**lib/example_web.ex**

```elixir
defmodule ExampleWeb do
# ...
  def router do
    quote do
      use Phoenix.Router, helpers: true # <-- Change this line
    # ...
```

## Create and configure the Repo

We use [AshPostgres](https://hexdocs.pm/ash_postgres/AshPostgres.html) to handle the database tables for our application. We need to create a new `Repo` module for that:

**lib/example/repo.ex**

```elixir
defmodule Example.Repo do
  use AshPostgres.Repo, otp_app: :example

  def installed_extensions do
    ["uuid-ossp", "citext"]
  end
end
```

We have to configure the Repo in `config/config.exs`. While doing that we also configure other stuff which we need later.

**config/config.exs**

```elixir
# ...

import Config

# add these lines -->
config :example, 
  ash_apis: [Example.Accounts]

config :example, 
  ecto_repos: [Example.Repo]

config :ash, 
  :use_all_identities_in_manage_relationship?, false
# <-- add these lines

# ...
```

We need to add the `Repo` to the supervision tree in `lib/example/application.ex`:

`** lib/example/application.ex **`

```elixir
defmodule Example.Application do
  # ...

  @impl true
  def start(_type, _args) do
    children = [
      # ...
      # add these lines -->
      Example.Repo,
      {AshAuthentication.Supervisor, otp_app: :example}
      # <-- add these lines
    ]
  # ...
```

### Database Configuration

In case you have other `usernames` and `passwords` for your database you need to change the following values. We use the default `postgres` user and password.

**config/dev.exs**

```elixir
import Config

# add these lines -->
config :example, Example.Repo, 
  username: "postgres", 
  password: "postgres", 
  hostname: "localhost", 
  database: "example_dev", 
  port: 5432, 
  show_sensitive_data_on_connection_error: true, 
  pool_size: 10
# <-- add these lines

# ...
```

**config/test.exs**

```elixir
import Config

# add these lines -->
config :example, Example.Repo, 
  username: "postgres", 
  password: "postgres", 
  hostname: "localhost", 
  database: "example_test#{System.get_env("MIX_TEST_PARTITION")}", 
  pool: Ecto.Adapters.SQL.Sandbox, 
  pool_size: 10
# <-- add these lines
```

**config/runtime.exs**

```elixir
import Config

# ...

if config_env() == :prod do
  # add these lines -->
  database_url = 
    System.get_env("DATABASE_URL") || 
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """ 

  config :example, Example.Repo, 
    url: database_url, 
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
  # <-- add these lines

# ...
```

## Create an Accounts API

We need to create an `Accounts` API in our application to provide a `User` and a `Token` resource. Strictly speaking we don't need the `Token` resource for the login with a password. But we'll need it later (e.g. for the password reset) so we just create it now while we are here.

At the end we should have the following directory structure:

```bash
lib/example
├── accounts
│   ├── registry.ex
│   ├── token.ex
│   └── user.ex
├── accounts.ex
...
```

**lib/example/accounts.ex**

```elixir
defmodule Example.Accounts do
  use Ash.Api

  resources do
    registry Example.Accounts.Registry
  end
end
```

**lib/example/accounts/user.ex**

```elixir
defmodule Example.Accounts.User do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
  end

  authentication do
    api Example.Accounts

    strategies do
      password :password do
        identity_field(:email)
      end
    end

    tokens do
      enabled?(true)
      token_resource(Example.Accounts.Token)

      signing_secret(Application.compile_env(:example, ExampleWeb.Endpoint)[:secret_key_base])
    end
  end

  postgres do
    table "users"
    repo Example.Repo
  end

  identities do
    identity :unique_email, [:email]
  end
end
```

**lib/example/accounts/token.ex**

```elixir
defmodule Example.Accounts.Token do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  token do
    api Example.Accounts
  end

  postgres do
    table "tokens"
    repo Example.Repo
  end
end
```

Next, let's define our registry:

**lib/example/accounts/registry.ex**

```elixir
defmodule Example.Accounts.Registry do
  use Ash.Registry, extensions: [Ash.Registry.ResourceValidations]

  entries do
    entry Example.Accounts.User
    entry Example.Accounts.Token
  end
end
```

### Migration and Create

Now is a good time to create the database and run the migrations:

```bash
$ mix ash_postgres.create
$ mix ash_postgres.generate_migrations --name add_user_and_token
$ mix ash_postgres.migrate
```

> In case you want to drop the database and start over again during development you can use `mix ash_postgres.drop` followed by `mix ash_postgres.create` and `mix ash_postgres.migrate`.

## `AshAuthentication.Phoenix.Router`

`ash_authentication_phoenix` includes several helper macros which can generate
Phoenix routes for you. For that you need to add 6 lines in the router module:

**lib/example_web/router.ex**

```elixir
defmodule ExampleWeb.Router do
  use ExampleWeb, :router
  use AshAuthentication.Phoenix.Router # <--- Add this line

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {ExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session           # <--- Add this line
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer            # <--- Add this line
  end

  scope "/", ExampleWeb do
    pipe_through :browser

    get "/", PageController, :home

    # add these lines -->
    sign_in_route()
    sign_out_route AuthController
    auth_routes_for Example.Accounts.User, to: AuthController 
    reset_route []
    # <-- add these lines

  end
# ...
```

### Generated routes

Given the above configuration you should see the following in your routes:

```
# mix phx.routes

Generated example app
          auth_path  GET  /sign-in                               AshAuthentication.Phoenix.SignInLive :sign_in
          auth_path  GET  /sign-out                              ExampleWeb.AuthController :sign_out
          auth_path  *    /auth/user/password/register           ExampleWeb.AuthController {:user, :password, :register}
          auth_path  *    /auth/user/password/sign_in            ExampleWeb.AuthController {:user, :password, :sign_in}
          page_path  GET  /                                      ExampleWeb.PageController :home
...
```

## `AshAuthentication.Phoenix.Controller`

While running `mix phx.routes` you probably saw the warning message that the `ExampleWeb.AuthController.init/1 is undefined`. Let's fix that by creating a new controller:

**lib/my_app_web/controllers/auth_controller.ex**

```elixir
defmodule ExampleWeb.AuthController do
  use ExampleWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: return_to)
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_status(401)
    |> render("failure.html")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session()
    |> redirect(to: return_to)
  end
end
```

**lib/example_web/controllers/auth_html.ex**

```elixir
defmodule ExampleWeb.AuthHTML do
  use ExampleWeb, :html

  embed_templates "auth_html/*"
end
```

**lib/example_web/controllers/auth_html/failure.html.heex**

```html
<h1 class="text-2xl">Authentication Error</h1>
```

### Tailwind

If you plan on using our default [Tailwind](https://tailwindcss.com/)-based
components without overriding them you will need to modify your
`assets/tailwind.config.js` to include the `ash_authentication_phoenix`
dependency:

**assets/tailwind.config.js**

```javascript
// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/*_web.ex",
    "../lib/*_web/**/*.*ex",
    "../deps/ash_authentication_phoenix/**/*.ex"  // <-- Add this line
  ],
  // ...
```

## Minimal Example

To see how the authentication works we replace the default Phoenix `home.html.eex` with a minimal example which has a top navbar. On the right side it shows the `@current_user` and a sign out button. If you are not signed in you will see a sign in button.

**lib/example_web/controllers/page_html/home.html.heex**

```html
<nav class="bg-gray-800">
  <div class="px-2 mx-auto max-w-7xl sm:px-6 lg:px-8">
    <div class="relative flex items-center justify-between h-16">
      <div class="flex items-center justify-center flex-1 sm:items-stretch sm:justify-start">
        <div class="block ml-6">
          <div class="flex space-x-4">
            <div class="px-3 py-2 text-xl font-medium text-white ">
              Ash Demo
            </div>
          </div>
        </div>
      </div>
      <div class="absolute inset-y-0 right-0 flex items-center pr-2 sm:static sm:inset-auto sm:ml-6 sm:pr-0">
        <%= if @current_user do %>
          <span class="px-3 py-2 text-sm font-medium text-white rounded-md">
            <%= @current_user.email %>
          </span>
          <a
            href="/sign-out"
            class="rounded-lg bg-zinc-100 px-2 py-1 text-[0.8125rem] font-semibold leading-6 text-zinc-900 hover:bg-zinc-200/80 active:text-zinc-900/70"
          >
            Sign out
          </a>
        <% else %>
          <a
            href="/sign-in"
            class="rounded-lg bg-zinc-100 px-2 py-1 text-[0.8125rem] font-semibold leading-6 text-zinc-900 hover:bg-zinc-200/80 active:text-zinc-900/70"
          >
            Sign In
          </a>
        <% end %>
      </div>
    </div>
  </div>
</nav>

<div class="py-10">
  <header>
    <div class="px-4 mx-auto max-w-7xl sm:px-6 lg:px-8">
      <h1 class="text-3xl font-bold leading-tight tracking-tight text-gray-900">Demo</h1>
    </div>
  </header>
  <main>
    <div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
      <div class="px-4 py-8 sm:px-0">
        <div class="border-4 border-gray-200 border-dashed rounded-lg h-96"></div>
      </div>
    </div>
  </main>
</div>
```

## Start Phoenix

You can now start Phoenix and visit
[`localhost:4000`](http://localhost:4000) from your browser.

```bash
$ mix phx.server
```

### Sign In

Visit [`localhost:4000/sign-in`](http://localhost:4000/sign-in) from your browser.

The sign in page shows a link to register a new account.

### Sign Out

Visit [`localhost:4000/sign-out`](http://localhost:4000/sign-out) from your browser.

## Reset Password

In this section we add a reset password functionality. Which is triggered by adding `resettable` in the `User` resource. Please replace the `strategies` block in `lib/example/accounts/user.ex` with the following code: 

**lib/example/accounts/user.ex**

```elixir
# [...]
strategies do
  password :password do
    identity_field(:email)
    hashed_password_field(:hashed_password)

    resettable do
      sender(Example.Accounts.User.Senders.SendPasswordResetEmail)
    end
  end
end
# [...]
```

Do make this work we need to create a new module `Example.Accounts.User.Senders.SendPasswordResetEmail`:

**lib/example/accounts/user/senders/send_password_reset_email.ex**

```elixir
defmodule Example.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """
  use AshAuthentication.Sender
  use ExampleWeb, :verified_routes

  def send(user, token, _) do
    Example.Accounts.Emails.deliver_reset_password_instructions(
      user,
      url(~p"/password-reset/#{token}")
    )
  end
end
```

We also need to create a new email template:

**lib/example/accounts/emails.ex**
  
```elixir
defmodule Example.Accounts.Emails do
  @moduledoc """
  Delivers emails.
  """

  import Swoosh.Email

  def deliver_reset_password_instructions(user, url) do
    if !url do
      raise "Cannot deliver reset instructions without a url"
    end

    deliver(user.email, "Reset Your Password", """
    <html>
      <p>
        Hi #{user.email},
      </p>

      <p>
        <a href="#{url}">Click here</a> to reset your password.
      </p>

      <p>
        If you didn't request this change, please ignore this.
      </p>
    <html>
    """)
  end

  # For simplicity, this module simply logs messages to the terminal.
  # You should replace it by a proper email or notification tool, such as:
  #
  #   * Swoosh - https://hexdocs.pm/swoosh
  #   * Bamboo - https://hexdocs.pm/bamboo
  #
  defp deliver(to, subject, body) do
    IO.puts("Sending email to #{to} with subject #{subject} and body #{body}")

    new()
    |> from({"Zach", "zach@ash-hq.org"}) # TODO: Replace with your email
    |> to(to_string(to))
    |> subject(subject)
    |> put_provider_option(:track_links, "None")
    |> html_body(body)
    |> Example.Mailer.deliver!()
  end
end
```

Your new reset password functionality is active. Visit [`localhost:4000/sign-in`](http://localhost:4000/sign-in) with your browser and click on the `Forgot your password?` link to trigger the reset password workflow.