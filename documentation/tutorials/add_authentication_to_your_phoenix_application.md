# Add authentication to your Ash/Phoenix Application

## Who is this for?

This guide will show you how to restrict access and actions on your Ash Resources to authenticated user.

It builds on the [Ash Phoenix Getting Started Guide](https://hexdocs.pm/ash_phoenix/getting_started_with_ash_and_phoenix.html),
which we recommended to follow first.

## Goals

In this guide we will:

1. Set up AshAuthentication and AshAuthenticationPhoenix.
2. Create a basic Account.User resource with password and email.
3. Add an authentication flow to the blog with registration, sign up and password reset

## Setting up AshAuthenticationPhoenix

### Dependencies

AshAuthentication is used to add support for authentication to your resource.
AshAuthenticationPhoenix provides integration with the Phoenix Framework such as router helpers, plugs, and complete Sign In and Registration pages.

Add the `ash_authentication` and `ash_authentication_phoenix` dependencies to the `deps` function in your `mix.exs`.
Use `mix hex.info dependency_name` to get the latest version of each dependency.

```elixir
# mix.exs

def deps do
  [
    {:phoenix, "~> x.x"}
    ...
    {:ash, "~> x.x"},
    {:ash_postgres, "~> x.x"},
    {:ash_phoenix, "~> x.x"},
    # add these line -->
    {:ash_authentication, "~> x.x"},
    {:ash_authentication_phoenix, "~> x.x"}
    # <-- add these line
  ]
end
```

Install the dependencies by running:

```shell
mix deps.get
```

### Formatter

Add dependencies to your `.formatter.exs` as well, to ensure consistent formatting when using `mix format`. 

```elixir
[
  import_deps: [
    :phoenix,
    :ash,
    :ash_phoenix,
    :ash_postgres,
    # add these line -->
    :ash_authentication,
    :ash_authentication_phoenix
    # <-- add these line
    ],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}"]
]
```

### Phoenix 1.7 compatibility

For Phoenix 1.7 we need to change `helpers: false` to `helpers: true` in the router section:


```elixir
# lib/my_ash_phoenix_app.ex

defmodule MyAshPhoenixApplication do
# ...
  def router do
    quote do
      use Phoenix.Router, helpers: true # <-- Change this line
    # ...
```

### Tailwind

If you plan on using our default [Tailwind](https://tailwindcss.com/)-based
components without overriding them you will need to modify your
`assets/tailwind.config.js` to include the `ash_authentication_phoenix`
dependency:


```javascript
// assets/tailwind.config.js

// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/*_web.ex",
    "../lib/*_web/**/*.*ex",
    // Add next line (and comma on previous line) -->
    "../deps/ash_authentication_phoenix/**/*.ex" 
  ],
  // ...
}
```

### AshAuthentication Supervisor

We need to add `AshAuthentication.Supervisor` to the supervision tree in `lib/example/application.ex`:

`** lib/example/application.ex **`

```elixir
defmodule Example.Application do
  # ...

  @impl true
  def start(_type, _args) do
    children = [
      # ...
      # add next line -->
      {AshAuthentication.Supervisor, otp_app: :example}
    ]
  # ...
```

## Creating an `Accounts` Api, User and Token Resource

Consideration around accounts are better kept in a separate `Accounts` API.
In this section, we'll create this API, with a `User` resource that can be used for authentication.
The `Token` resource is not used to login with a password, but it is needed for the password reset.

The resulting directory structure should look like this:

```
lib/
├─ my_ash_phoenix_app/
│  ├─ accounts/
│  │  ├─ accounts.ex
│  │  ├─ registry.ex
│  │  ├─ resources/
│  │  │  ├─ user.ex
│  │  │  ├─ token.ex
│  ├─ blog/
│  │  ├─ blog.ex
│  │  ├─ registry.ex
│  │  ├─ resources/
│  │  │  ├─ post.ex
```

### The Accounts Api and Registry

We create the `Accounts` API (and Registry) the same way we did the `Blog` API in [the previous guide](https://hexdocs.pm/ash_phoenix/getting_started_with_ash_and_phoenix.html).


```elixir
# lib/my_ash_phoenix_app/accounts/accounts.ex

defmodule MyAshPhoenixApp.Accounts do
  use Ash.Api

  resources do
    registry MyAshPhoenixApp.Accounts.Registry
  end
end
```

```elixir
# lib/my_ash_phoenix_app/accounts/registry.ex

defmodule MyAshPhoenixApp.Accounts.Registry do
  use Ash.Registry,
    extensions: [
      Ash.Registry.ResourceValidations
    ]

  entries do
    entry MyAshPhoenixApp.Accounts.User
  end
end
```

Don't forget to activate the API in your config:

```elixir
# /config/config.exs

config :my_ash_phoenix_app,
  # Change this line -->
  ash_apis: [MyAshPhoenixApp.Accounts, MyAshPhoenixApp.Blog]
```

### The `user` resource

We create a minimal user resource.

The resource definition includes an `authentication` block,
that defines the strategies for authentication (password, magic link...).

```elixir
# lib/my_ash_phoenix_app/accounts/resources/user.ex

defmodule MyAshPhoenixApp.Accounts.User do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    # the AshAuthentication extension will provide the auth functionalities
    extensions: [AshAuthentication]

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
  end

  # describe authentication as a user 
  authentication do
    api MyAshPhoenixApp.Accounts

    # list the authentication strategies, here a single password strategy
    strategies do
      # enables password login, with email field as identifier
      password :password do
        identity_field :email
      end
    end


    # enable tokens for password reset
    tokens do
      enabled? true
      token_resource MyAshPhoenixApp.Accounts.Token

      signing_secret Application.compile_env(:my_ash_phoenix_app, MyAshPhoenixAppWeb.Endpoint)[
                       :secret_key_base
                     ]
    end
  end

  postgres do
    table "users"
    repo MyAshPhoenixApp.Repo
  end

  identities do
    identity :unique_email, [:email]
  end
end
```

### The `Token` resource

Token resource are a special kind of resource provided by AshAuthentication.
There is little to do with them except describe the storage with Postgres.

```elixir
# lib/my_ash_phoenix_app/accounts/token.ex

defmodule MyAshPhoenixApp.Accounts.Token do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  token do
    api MyAshPhoenixApp.Accounts
  end

  postgres do
    table "tokens"
    repo MyAshPhoenixApp.Repo
  end
end
```

### Migrating the database

Create and apply the database migrations to create the tables for your `User` and `Token` resources.

```shell
mix ash_postgres.generate_migrations --name add_user_and_token
mix ash_postgres.migrate
```

## Adding the Authentication Flow to the Blog

### `Router` Setup

`ash_authentication_phoenix` includes several helper macros which can generate Phoenix routes for you.
Make use of them to extend your web apps's `Router`.


```elixir
# lib/example_web/router.ex

defmodule MyAshPhoenixAppWeb.Router do
  use ExampleWeb, :router
  # Add the next line -->
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    # ...
    # Add the next line -->
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    # Add the next line -->
    plug :load_from_bearer
  end

  scope "/", MyAshPhoenixAppWeb do
    pipe_through :browser

    get "/", PageController, :index
    live "/posts", ExampleLiveView

    # add these lines -->
    sign_in_route()
    sign_out_route AuthController
    auth_routes_for MyAshPhoenixApp.Accounts.User, to: AuthController
    reset_route []
    # <-- add these lines
  end

  # ...
end
```

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

### The `AuthController`

If you have run `mix phx.routes` you probably saw a warning: `MyAshPhoenixAppWeb.AuthController.init/1 is undefined`.

In our `Router` the authentication routes point `AuthController`
which performs the actions (creating users, creating and deleting sessions...),
and redirections necessary to your authentication flow.

Create the `AuthController` module as follows:

```elixir
# lib/my_ash_phoenix_app_web/controllers/auth_controller.ex

defmodule MyAshPhoenixAppWeb.AuthController do
  use MyAshPhoenixAppWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, _token) do
    return_to = get_session(conn, :return_to) || Routes.page_path(conn, :index)

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: return_to)
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_status(302)
    |> put_flash(:error, "You couldn't sign in.")
    |> redirect(to: Routes.page_path(conn, :sign_in))
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || Routes.page_path(conn, :home)

    conn
    |> clear_session()
    |> redirect(to: return_to)
  end
end
```

### Display current user info on the homepage

To see how the authentication works we replace the default Phoenix `home.html.eex` with a minimal example which has a top navbar. On the right side it shows the `@current_user` and a sign out button. If you are not signed in you will see a sign in button.


```html
# lib/example_web/controllers/page_html/index.html.heex

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

### Try it out

#### Start Phoenix

You can now start Phoenix and visit
[`localhost:4000`](http://localhost:4000) from your browser.

```bash
$ mix phx.server
```

#### Sign In

Visit [`localhost:4000/sign-in`](http://localhost:4000/sign-in) from your browser.

The sign in page shows a link to register a new account.

#### Sign Out

Visit [`localhost:4000/sign-out`](http://localhost:4000/sign-out) from your browser.

### Adding Passowrd Reset

In this section we add a reset password functionality. Which is triggered by adding `resettable` in the `User` resource. Please replace the `strategies` block in `lib/example/accounts/user.ex` with the following code: 


```elixir
# lib/my_ash_phoenix_app/accounts/user.ex

# [...]
strategies do
  password :password do
    identity_field(:email)

    resettable do
      sender(MyAshPhoenixApp.Accounts.User.Senders.SendPasswordResetEmail)
    end
  end
end
# [...]
```

To make this work we need to create a new module `MyAshPhoenixApp.Accounts.User.Senders.SendPasswordResetEmail`:

```elixir
# lib/example/accounts/user/senders/send_password_reset_email.ex

defmodule Example.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """
  use AshAuthentication.Sender
  use MyAshPhoenixAppWeb, :verified_routes

  def send(user, token, _) do
    MyAshPhoenixApp.Accounts.Emails.deliver_reset_password_instructions(
      user,
      url(~p"/password-reset/#{token}")
    )
  end
end
```

We also need to create a new email template:

  
```elixir
# lib/example/accounts/emails.ex

defmodule MyAshPhoenixApp.Accounts.Emails do
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
