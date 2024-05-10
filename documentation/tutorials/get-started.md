# Getting Started Ash Authentication Phoenix

In this step-by-step tutorial we create a new empty `Example` Phoenix + Ash application which provides the functionality for authentication. For beginners it is the best to follow the tutorial in the given order. For more advanced users it is a good reference to pick and choose from.

We assumes that you have [Elixir](https://elixir-lang.org) version 1.14.x (check with `elixir -v`) and Phoenix 1.7 (check with `mix phx.new --version`) installed. We also assume that you have a [PostgreSQL](https://www.postgresql.org) database running which we use to persist the user data.

## Green Field Phoenix Application

We start with a new Phoenix application:

```bash
$ mix phx.new example
$ cd example
```

## Basic Ash Setup

### Application Dependencies

We need to add the following dependencies. Use `mix hex.info dependency_name` to get the latest version of each dependency.

**mix.exs**

```elixir
defmodule Example.MixProject do
  use Mix.Project
  # ...

    defp deps do
    [
      # ...
      # add these lines -->
      {:ash, "~> x.x"},
      {:ash_authentication, "~> x.x"},
      {:ash_authentication_phoenix, "~> x.x"},
      {:ash_postgres, "~> x.x"}
      # <-- add these lines
    ]
  end
  # ...
```

Let's fetch everything:

```bash
$ mix deps.get
```

### Formatter

We can make our life easier and the code more consistent by adding formatters to the project. We will use [Elixir's built-in formatter](https://hexdocs.pm/mix/master/Mix.Tasks.Format.html) for this.

**.formatter.exs**

```elixir
[
  import_deps: [
    :phoenix,
    # add these lines -->
    :ash,
    :ash_authentication,
    :ash_authentication_phoenix,
    :ash_postgres
    # <-- add these lines
    ],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}"]
]
```

### Phoenix 1.7 compatibility

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

### Tailwind

If you plan on using our default [Tailwind](https://tailwindcss.com/)-based
components without overriding them you will need to modify your
`assets/tailwind.config.js` to include the `ash_authentication_phoenix`
dependency:

**assets/tailwind.config.js**

```javascript
// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin");

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/*_web.ex",
    "../lib/*_web/**/*.*ex",
    "../deps/ash_authentication_phoenix/**/*.*ex", // <-- Add this line
  ],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    plugin(({ addVariant }) =>
      addVariant("phx-no-feedback", [".phx-no-feedback&", ".phx-no-feedback &"])
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-click-loading", [
        ".phx-click-loading&",
        ".phx-click-loading &",
      ])
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-submit-loading", [
        ".phx-submit-loading&",
        ".phx-submit-loading &",
      ])
    ),
    plugin(({ addVariant }) =>
      addVariant("phx-change-loading", [
        ".phx-change-loading&",
        ".phx-change-loading &",
      ])
    ),
  ],
};
```

## AshPostgres.Repo Setup

We use [AshPostgres](https://hexdocs.pm/ash_postgres/AshPostgres.html) to handle the database tables for our application. We need to replace the content of the `Repo` module with the following code:

**lib/example/repo.ex**

```elixir
defmodule Example.Repo do
  use AshPostgres.Repo, otp_app: :example

  def installed_extensions do
    ["uuid-ossp", "citext", "ash-functions"]
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
  ash_domains: [Example.Accounts]
# ...
```

We need to add `AshAuthentication.Supervisor` to the supervision tree in `lib/example/application.ex`:

`** lib/example/application.ex **`

```elixir
defmodule Example.Application do
  # ...

  @impl true
  def start(_type, _args) do
    children = [
      # ...
      # add this line -->
      {AshAuthentication.Supervisor, otp_app: :example}
      # <-- add this line
    ]
  # ...
```

## Accounts Api and Resources

We need to create an `Accounts` Api in our application to provide a `User` and a `Token` resource. Strictly speaking we don't need the `Token` resource for just the login with a password. But we'll need it later (e.g. for the password reset) so we just create it now while we are here.

At the end we should have the following directory structure:

```bash
lib/example
├── accounts
|   ├── accounts.ex
|   ├── secrets.ex
|   └── resources
│       ├── token.ex
|       └── user.ex
...
```

**lib/example/accounts/resources/user.ex**

```elixir
defmodule Example.Accounts.User do
  use Ash.Resource,
    domain: Example.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
  end

  authentication do
    strategies do
      password :password do
        identity_field :email
      end
    end

    tokens do
      token_resource Example.Accounts.Token
      signing_secret Example.Accounts.Secrets
    end
  end

  postgres do
    table "users"
    repo Example.Repo
  end

  identities do
    identity :unique_email, [:email]
  end

  # If using policies, add the following bypass:
  # policies do
  #   bypass AshAuthentication.Checks.AshAuthenticationInteraction do
  #     authorize_if always()
  #   end
  # end
end
```

**lib/example/accounts/secrets.ex**

```elixir
defmodule Example.Accounts.Secrets do
  use AshAuthentication.Secret


  def secret_for([:authentication, :tokens, :signing_secret], Example.Accounts.User, _) do
    case Application.fetch_env(:example, ExampleWeb.Endpoint) do
      {:ok, endpoint_config} ->
        Keyword.fetch(endpoint_config, :secret_key_base)
      :error ->
        :error
    end
  end
end
```

**lib/example/accounts/resources/token.ex**

```elixir
defmodule Example.Accounts.Token do
  use Ash.Resource,
    domain: Example.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table "tokens"
    repo Example.Repo
  end

  # If using policies, add the following bypass:
  # policies do
  #   bypass AshAuthentication.Checks.AshAuthenticationInteraction do
  #     authorize_if always()
  #   end
  # end
end
```

**lib/example/accounts/accounts.ex**

```elixir
defmodule Example.Accounts do
  use Ash.Domain

  resources do
    resource Example.Accounts.User
    resource Example.Accounts.Token
  end
end
```

### Add to config

Although mentioned in a step at the top, a common mistake here is not to add the new api into your `ash_apis` config in `config/config.exs`. It should look like this:

```elixir
config :example,
  ash_apis: [..., Example.Accounts]
```

### Create and Migration

Now is a good time to create the database and run the migrations. You have to use specific `ash_postgres` mix tasks for that:

```bash
$ mix ash_postgres.create
$ mix ash_postgres.generate_migrations --name add_user_and_token
$ mix ash_postgres.migrate
```

> In case you want to drop the database and start over again during development you can use `mix ash_postgres.drop` followed by `mix ash_postgres.create` and `mix ash_postgres.migrate`.

## Router Setup

`ash_authentication_phoenix` includes several helper macros which can generate
Phoenix routes for you. For that you need to add 6 lines in the router module or just replace the whole file with the following code:

**lib/example_web/router.ex**

```elixir
defmodule ExampleWeb.Router do
  use ExampleWeb, :router
  # Add this line
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {ExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # Add the next line
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    # Add the next line
    plug :load_from_bearer
  end

  scope "/", ExampleWeb do
    pipe_through :browser

    get "/", PageController, :home

    # add these lines -->
    # Leave out `register_path` and `reset_path` if you don't want to support
    # user registration and/or password resets respectively.
    sign_in_route(register_path: "/register", reset_path: "/reset")
    sign_out_route AuthController
    auth_routes_for Example.Accounts.User, to: AuthController
    reset_route []
    # <-- add these lines
  end

  # Other scopes may use custom stacks.
  # scope "/api", ExampleWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:example, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ExampleWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
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

### Customizing the generated routes

If you're integrating AshAuthentication into an existing app, you probably already have existing HTML layouts you want to use, to wrap the provided sign in/forgot password/etc. forms.

Liveviews provided by AshAuthentication.Phoenix will use the same root layout configured in your router's `:browser` pipeline, but it includes its own layout file primarily for rendering flash messages.

If you would like to use your own layout file instead, you can specify this as an option to the route helpers, eg.

```elixir
reset_route(layout: {MyAppWeb, :live})
```

## AuthController

While running `mix phx.routes` you probably saw the warning message that the `ExampleWeb.AuthController.init/1 is undefined`. Let's fix that by creating a new controller:

**lib/example_web/controllers/auth_controller.ex**

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
    |> put_flash(:error, "Incorrect email or password")
    |> redirect(to: ~p"/sign-in")
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

## Example home.html.heex

To see how the authentication works we replace the default Phoenix `home.html.eex` with a minimal example which has a top navbar. On the right side it shows the `@current_user` and a sign out button. If you are not signed in you will see a sign in button.

**lib/example_web/controllers/page_html/home.html.heex**

```html
<nav class="bg-gray-800">
  <div class="px-2 mx-auto max-w-7xl sm:px-6 lg:px-8">
    <div class="relative flex items-center justify-between h-16">
      <div
        class="flex items-center justify-center flex-1 sm:items-stretch sm:justify-start"
      >
        <div class="block ml-6">
          <div class="flex space-x-4">
            <div class="px-3 py-2 text-xl font-medium text-white ">
              Ash Demo
            </div>
          </div>
        </div>
      </div>
      <div
        class="absolute inset-y-0 right-0 flex items-center pr-2 sm:static sm:inset-auto sm:ml-6 sm:pr-0"
      >
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
      <h1 class="text-3xl font-bold leading-tight tracking-tight text-gray-900">
        Demo
      </h1>
    </div>
  </header>
  <main>
    <div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
      <div class="px-4 py-8 sm:px-0">
        <div
          class="border-4 border-gray-200 border-dashed rounded-lg h-96"
        ></div>
      </div>
    </div>
  </main>
</div>
```

### If you are using LiveView

If you are using LiveView, jump over to the [Use AshAuthentication with LiveView](/documentation/tutorials/use-ash-authentication-with-liveview.md)
section and set up your LiveView routes for `AshAuthentication`. Once that is done, you can proceed with the following steps.

### Start Phoenix

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

### Debugging the Authentication flow

The default authentication view shows a generic error message to users if their sign-in fails, like "Email or password was incorrect". This is for security purposes - you don't want potentially malicious people to know if an email address definitively exists in your system.

However, if you're having issues setting up AshAuthentication, or trying to debug issues with your implementation, that error message isn't super useful to figure out what's going wrong.

To that end, AshAuthentication comes with debug functionality that can be enabled in dev:

**config/dev.exs**

```elixir
config :ash_authentication, debug_authentication_failures?: true
```

> #### Don't enable debugging outside `dev` environments! {: .warning}
>
> This could leak users' personally-identifiable information (PII) into your logs on failed sign-in attempts - a security issue!

Once the config is added, you can restart your dev server and test what happens when you visit the sign-in page and submit invalid credentials. You should see log messages like -

```text
[timestamp] [warning] Authentication failed: Query returned no users

Details: %AshAuthentication.Errors.AuthenticationFailed{
  field: nil,
  strategy: %AshAuthentication.Strategy.Password{
    confirmation_required?: true,
    ...
```

## Reset Password

In this section we add a reset password functionality. Which is triggered by adding `resettable` in the `User` resource. Please replace the `strategies` block in `lib/example/accounts/resources/user.ex` with the following code:

**lib/example/accounts/resources/user.ex**

```elixir
# [...]
strategies do
  password :password do
    identity_field :email

    resettable do
      sender Example.Accounts.User.Senders.SendPasswordResetEmail
    end
  end
end
# [...]
```

To make this work we need to create a new module `Example.Accounts.User.Senders.SendPasswordResetEmail`:

**lib/example/accounts/user/senders/send_password_reset_email.ex**

```elixir
defmodule Example.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """
  use AshAuthentication.Sender
  use ExampleWeb, :verified_routes

  @impl AshAuthentication.Sender
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
