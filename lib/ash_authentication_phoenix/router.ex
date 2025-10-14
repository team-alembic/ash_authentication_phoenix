# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Router do
  @moduledoc """
  Phoenix route generation for AshAuthentication.

  Using this module imports the macros in this module and the plug functions
  from `AshAuthentication.Phoenix.Plug`.

  ## Usage

  Adding authentication to your live-view router is very simple:

  ```elixir
  defmodule MyAppWeb.Router do
    use MyAppWeb, :router
    use AshAuthentication.Phoenix.Router

    pipeline :browser do
      # ...
      plug(:load_from_session)
    end

    pipeline :api do
      # ...
      plug(:load_from_bearer)
    end

    scope "/", MyAppWeb do
      pipe_through :browser
      sign_in_route auth_routes_prefix: "/auth"
      sign_out_route AuthController
      auth_routes AuthController, MyApp.Accounts.User
      reset_route auth_routes_prefix: "/auth"
    end
  ```
  """

  require Logger

  @typedoc "Options that can be passed to `auth_routes_for`."
  @type auth_route_options :: [path_option | to_option | scope_opts_option]

  @typedoc "A sub-path if required.  Defaults to `/auth`."
  @type path_option :: {:path, String.t()}

  @typedoc "The controller which will handle success and failure."
  @type to_option :: {:to, AshAuthentication.Phoenix.Controller.t()}

  @typedoc "Any options which should be passed to the generated scope."
  @type scope_opts_option :: {:scope_opts, keyword}

  @doc false
  @spec __using__(any) :: Macro.t()
  defmacro __using__(_) do
    quote do
      import AshAuthentication.Phoenix.Router
      import AshAuthentication.Phoenix.Plug
      import AshAuthentication.Phoenix.LiveSession, only: :macros
    end
  end

  @doc """
  Generates the routes needed for the various strategies for a given
  AshAuthentication resource.

  This is required if you wish to use authentication.

  ## Options

    * `to` - a module which implements the
      `AshAuthentication.Phoenix.Controller` behaviour.  This is required.
    * `path` - a string (starting with "/") wherein to mount the generated
      routes.
    * `scope_opts` - any options to pass to the generated scope.

  ## Example

  ```elixir
  scope "/", DevWeb do
    auth_routes_for(MyApp.Accounts.User,
      to: AuthController,
      path: "/authentication",
      scope_opts: [host: "auth.example.com"]
    )
  end
  ```
  """
  @deprecated """
  Replaced by `auth_routes/2..3`.

  Run `mix igniter.apply_upgrades ash_authentication_phoenix:2.10.5:2.10.6` to fix automatically.
  """
  @spec auth_routes_for(Ash.Resource.t(), auth_route_options) :: Macro.t()
  defmacro auth_routes_for(resource, opts) when is_list(opts) do
    quote location: :keep do
      subject_name = AshAuthentication.Info.authentication_subject_name!(unquote(resource))
      controller = Keyword.fetch!(unquote(opts), :to)
      path = Keyword.get(unquote(opts), :path, "/auth")

      path =
        if String.starts_with?(path, "/") do
          path
        else
          "/" <> path
        end

      scope_opts = Keyword.get(unquote(opts), :scope_opts, [])

      strategies =
        AshAuthentication.Info.authentication_add_ons(unquote(resource)) ++
          AshAuthentication.Info.authentication_strategies(unquote(resource))

      scope path, scope_opts do
        for strategy <- strategies do
          for {path, phase} <- AshAuthentication.Strategy.routes(strategy) do
            match AshAuthentication.Strategy.method_for_phase(strategy, phase),
                  path,
                  controller,
                  {subject_name, AshAuthentication.Strategy.name(strategy), phase},
                  as: :auth,
                  private: %{strategy: strategy}
          end
        end
      end
    end
  end

  @doc """
  Generates the routes needed for the various strategies for a given
  AshAuthentication resource.

  This matches *all* routes at the provided `path`, which defaults to `/auth`. This means that
  if you have any other routes that begin with `/auth`, you will need to make sure this
  appears after them.

  ## Upgrading from `auth_routes_for/2`

  If you are using route helpers anywhere in your application, typically looks like `Routes.auth_path/3`
  or `Helpers.auth_path/3` you will need to update them to use verified routes. To see what routes are
  available to you, use `mix ash_authentication.phoenix.routes`.

  If you are using any of the components provided by `AshAuthenticationPhoenix`, you will need to supply
  them with the `auth_routes_prefix` assign, set to the `path` you provide here (set to `/auth` by default).

  You also will need to set `auth_routes_prefix` on the `reset_route`, i.e `reset_route(auth_routes_prefix: "/auth")`

  ## Options

  * `path` - the path to mount auth routes at. Defaults to `/auth`. If changed, you will also want
    to change the `auth_routes_prefix` option in `sign_in_route` to match.
    routes.
  * `not_found_plug` - a plug to call if no route is found. By default, it renders a simple JSON
    response with a 404 status code.
  * `as` - the alias to use for the generated scope. Defaults to `:auth`.
  """
  @spec auth_routes(
          auth_controller :: module(),
          Ash.Resource.t() | list(Ash.Resource.t()),
          auth_route_options
        ) :: Macro.t()
  defmacro auth_routes(auth_controller, resource_or_resources, opts \\ []) when is_list(opts) do
    resource_or_resources =
      resource_or_resources
      |> List.wrap()
      |> Enum.map(&Macro.expand_once(&1, %{__CALLER__ | function: {:auth_routes, 2}}))

    quote location: :keep do
      opts = unquote(opts)
      path = Keyword.get(opts, :path, "/auth")
      not_found_plug = Keyword.get(opts, :not_found_plug)
      controller = Phoenix.Router.scoped_alias(__MODULE__, unquote(auth_controller))
      plug = Keyword.get(opts, :strategy_router_plug, AshAuthentication.Phoenix.StrategyRouter)

      scope "/", alias: false do
        forward path, plug,
          path: Phoenix.Router.scoped_path(__MODULE__, path),
          as: opts[:as] || :auth,
          controller: controller,
          not_found_plug: not_found_plug,
          resources: List.wrap(unquote(resource_or_resources))
      end
    end
  end

  @doc """
  Generates a generic, white-label sign-in page using LiveView and the
  components in `AshAuthentication.Phoenix.Components`.

  This is completely optional.

  Available options are:

  * `path` the path under which to mount the sign-in live-view. Defaults to `/sign-in` within the current router scope.
  * `auth_routes_prefix` if set, this will be used instead of route helpers when determining routes.
    Allows disabling `helpers: true`.
    If a tuple `{:unscoped, path}` is provided, the path prefix will not inherit the current route scope.
  * `register_path` - the path under which to mount the password strategy's registration live-view.
     If not set, and registration is supported, registration will use a dynamic toggle and will not be routeable to.
     If a tuple {:unscoped, path} is provided, the registration path will not inherit the current route scope.
  * `reset_path` - the path under which to mount the password strategy's password reset live-view, for a user to
    request a reset token by email. If not set, and password reset is supported, password reset will use a
    dynamic toggle and will not be routeable to. If a tuple {:unscoped, path} is provided, the reset path
    will not inherit the current route scope.
  * `resources` - Which resources should have their sign in UIs rendered. Defaults to all resources
    that use `AshAuthentication`.
  * `live_view` the name of the live view to render. Defaults to
    `AshAuthentication.Phoenix.SignInLive`.
  * `as` which is used to prefix the generated `live_session` and `live` route name. Defaults to `:auth`.
  * `otp_app` the otp app or apps to find authentication resources in. Pulls from the socket by default.
  * `overrides` specify any override modules for customisation.  See
    `AshAuthentication.Phoenix.Overrides` for more information.
  * `gettext_fn` as a `{module :: module, function :: atom}` tuple pointing to a
    `(msgid :: String.t(), bindings :: keyword) :: String.t()` typed function that will be called to translate
    each output text of the live view.
  * `gettext_backend` as a `{module :: module, domain :: String.t()}` tuple pointing to a Gettext backend module
    and specifying the Gettext domain. This is basically a convenience wrapper around `gettext_fn`.
  * `on_mount_prepend` - Same as `on_mount`, but for hooks that need to be run before AshAuthenticationPhoenix's hooks.

  All other options are passed to the generated `scope`.
  """
  @spec sign_in_route(
          opts :: [
            {:path, String.t()}
            | {:live_view, module}
            | {:as, atom}
            | {:on_mount, [module]}
            | {:overrides, [module]}
            | {:gettext_fn, {module, atom}}
            | {:gettext_backend, {module, String.t()}}
            | {:on_mount_prepend, [module]}
            | {atom, any}
          ]
        ) :: Macro.t()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro sign_in_route(opts \\ []) do
    {path, opts} = Keyword.pop(opts, :path, "/sign-in")
    {live_view, opts} = Keyword.pop(opts, :live_view, AshAuthentication.Phoenix.SignInLive)
    {as, opts} = Keyword.pop(opts, :as, :auth)
    {otp_app, opts} = Keyword.pop(opts, :otp_app)
    {resources, opts} = Keyword.pop(opts, :resources)
    {layout, opts} = Keyword.pop(opts, :layout)
    {on_mount, opts} = Keyword.pop(opts, :on_mount)
    {reset_path, opts} = Keyword.pop(opts, :reset_path)
    {register_path, opts} = Keyword.pop(opts, :register_path)
    {auth_routes_prefix, opts} = Keyword.pop(opts, :auth_routes_prefix)
    {gettext_fn, opts} = Keyword.pop(opts, :gettext_fn)
    {gettext_backend, opts} = Keyword.pop(opts, :gettext_backend)
    {on_mount_prepend, opts} = Keyword.pop(opts, :on_mount_prepend)

    {overrides, opts} =
      Keyword.pop(opts, :overrides, [AshAuthentication.Phoenix.Overrides.Default])

    gettext_fn =
      maybe_generate_gettext_fn_pointer(gettext_fn, gettext_backend, __CALLER__.module, path)

    opts =
      opts
      |> Keyword.put_new(:alias, false)

    quote do
      scope "/", unquote(opts) do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        on_mount =
          (List.wrap(unquote(on_mount_prepend)) ++
             [
               AshAuthentication.Phoenix.Router.OnLiveViewMount,
               AshAuthentication.Phoenix.LiveSession | unquote(on_mount || [])
             ])
          |> Enum.uniq_by(fn
            {mod, _} -> mod
            mod -> mod
          end)

        sign_in_path = Phoenix.Router.scoped_path(__MODULE__, unquote(path))

        register_path =
          case unquote(register_path) do
            nil -> nil
            {:unscoped, value} -> value
            value -> Phoenix.Router.scoped_path(__MODULE__, value)
          end

        reset_path =
          case unquote(reset_path) do
            nil -> nil
            {:unscoped, value} -> value
            value -> Phoenix.Router.scoped_path(__MODULE__, value)
          end

        auth_routes_prefix =
          case unquote(auth_routes_prefix) do
            nil -> nil
            {:unscoped, value} -> value
            value -> Phoenix.Router.scoped_path(__MODULE__, value)
          end

        live_session_opts = [
          session:
            {AshAuthentication.Phoenix.Router, :generate_session,
             [
               %{
                 "overrides" => unquote(overrides),
                 "auth_routes_prefix" => auth_routes_prefix,
                 "otp_app" => unquote(otp_app),
                 "resources" => unquote(resources),
                 "path" => sign_in_path,
                 "reset_path" => reset_path,
                 "register_path" => register_path,
                 "gettext_fn" => unquote(gettext_fn)
               }
             ]},
          on_mount: on_mount
        ]

        live_session_opts =
          case unquote(layout) do
            nil ->
              live_session_opts

            layout ->
              Keyword.put(live_session_opts, :layout, layout)
          end

        live_session :"#{unquote(as)}_sign_in", live_session_opts do
          live(unquote(path), unquote(live_view), :sign_in, as: unquote(as))

          if reset_path do
            live(reset_path, unquote(live_view), :reset, as: :"#{unquote(as)}_reset")
          end

          if register_path do
            live(register_path, unquote(live_view), :register, as: :"#{unquote(as)}_register")
          end
        end
      end

      unquote(generate_gettext_fn(gettext_backend, path))
    end
  end

  @doc """
  Generates a sign-out route which points to the `sign_out` action in your auth
  controller.

  This is optional, but you probably want it.
  """
  @spec sign_out_route(AshAuthentication.Phoenix.Controller.t(), path :: String.t(), [
          {:as, atom} | {atom, any}
        ]) :: Macro.t()
  defmacro sign_out_route(auth_controller, path \\ "/sign-out", opts \\ []) do
    {as, opts} = Keyword.pop(opts, :as, :auth)

    quote do
      scope unquote(path), unquote(opts) do
        get("/", unquote(auth_controller), :sign_out, as: unquote(as))
      end
    end
  end

  @doc """
  Generates a generic, white-label password reset page using LiveView and the components in
  `AshAuthentication.Phoenix.Components`. This is the page that allows a user to actually change his password,
  after requesting a reset token via the sign-in (`/reset`) route.

  Available options are:

  * `path` the path under which to mount the live-view. Defaults to
    `/password-reset`.
  * `auth_routes_prefix` if set, this will be used instead of route helpers when determining routes.
    Allows disabling `helpers: true`.
    If a tuple `{:unscoped, path}` is provided, the path prefix will not inherit the current route scope.
  * `live_view` the name of the live view to render. Defaults to
    `AshAuthentication.Phoenix.ResetLive`.
  * `as` which is passed to the generated `live` route. Defaults to `:auth`.
  * `overrides` specify any override modules for customisation. See
    `AshAuthentication.Phoenix.Overrides` for more information.
  * `gettext_fn` as a `{module :: module, function :: atom}` tuple pointing to a
    `(msgid :: String.t(), bindings :: keyword) :: String.t()` typed function that will be called to translate
    each output text of the live view.
  * `gettext_backend` as a `{module :: module, domain :: String.t()}` tuple pointing to a Gettext backend module
    and specifying the Gettext domain. This is basically a convenience wrapper around `gettext_fn`.

  All other options are passed to the generated `scope`.
  """
  @spec reset_route(
          opts :: [
            {:path, String.t()}
            | {:live_view, module}
            | {:as, atom}
            | {:overrides, [module]}
            | {:gettext_fn, {module, atom}}
            | {:gettext_backend, {module, String.t()}}
            | {:on_mount, [module]}
            | {:on_mount_prepend, [module]}
            | {atom, any}
          ]
        ) :: Macro.t()
  defmacro reset_route(opts \\ []) do
    {path, opts} = Keyword.pop(opts, :path, "/password-reset")
    {live_view, opts} = Keyword.pop(opts, :live_view, AshAuthentication.Phoenix.ResetLive)
    {as, opts} = Keyword.pop(opts, :as, :auth)
    {otp_app, opts} = Keyword.pop(opts, :otp_app)
    {layout, opts} = Keyword.pop(opts, :layout)
    {on_mount, opts} = Keyword.pop(opts, :on_mount)
    {on_mount_prepend, opts} = Keyword.pop(opts, :on_mount_prepend)
    {auth_routes_prefix, opts} = Keyword.pop(opts, :auth_routes_prefix)
    {gettext_fn, opts} = Keyword.pop(opts, :gettext_fn)
    {gettext_backend, opts} = Keyword.pop(opts, :gettext_backend)

    {overrides, opts} =
      Keyword.pop(opts, :overrides, [AshAuthentication.Phoenix.Overrides.Default])

    gettext_fn =
      maybe_generate_gettext_fn_pointer(gettext_fn, gettext_backend, __CALLER__.module, path)

    opts =
      opts
      |> Keyword.put_new(:alias, false)

    quote do
      auth_routes_prefix =
        case unquote(auth_routes_prefix) do
          nil -> nil
          {:unscoped, value} -> value
          value -> Phoenix.Router.scoped_path(__MODULE__, value)
        end

      scope unquote(path), unquote(opts) do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        on_mount =
          (List.wrap(unquote(on_mount_prepend)) ++
             [
               AshAuthentication.Phoenix.Router.OnLiveViewMount,
               AshAuthentication.Phoenix.LiveSession | unquote(on_mount || [])
             ])
          |> Enum.uniq_by(fn
            {mod, _} -> mod
            mod -> mod
          end)

        live_session_opts = [
          session:
            {AshAuthentication.Phoenix.Router, :generate_session,
             [
               %{
                 "auth_routes_prefix" => auth_routes_prefix,
                 "overrides" => unquote(overrides),
                 "gettext_fn" => unquote(gettext_fn),
                 "otp_app" => unquote(otp_app)
               }
             ]},
          on_mount: on_mount
        ]

        live_session_opts =
          case unquote(layout) do
            nil ->
              live_session_opts

            layout ->
              Keyword.put(live_session_opts, :layout, layout)
          end

        live_session :"#{unquote(as)}_reset", live_session_opts do
          live("/:token", unquote(live_view), :reset, as: unquote(as))
        end
      end

      unquote(generate_gettext_fn(gettext_backend, path))
    end
  end

  @doc """
  Generates a generic, white-label confirmation page using LiveView and the components in
  `AshAuthentication.Phoenix.Components`.

  This is used when `require_interaction?` is set to `true` on a confirmation strategy.

  Available options are:

  * `path` the path under which to mount the live-view. Defaults to
  * `auth_routes_prefix` if set, this will be used instead of route helpers when determining routes.
    Allows disabling `helpers: true`.
    If a tuple `{:unscoped, path}` is provided, the path prefix will not inherit the current route scope.
    "/<strategy>".
  * `token_as_route_param?` whether to use the token as a route parameter. i.e `<path>/:token`. Defaults to `true`.
  * `live_view` the name of the live view to render. Defaults to
    `AshAuthentication.Phoenix.ConfirmLive`.
  * `as` which is passed to the generated `live` route. Defaults to `:auth`.
  * `overrides` specify any override modules for customisation. See
    `AshAuthentication.Phoenix.Overrides` for more information.
  * `gettext_fn` as a `{module :: module, function :: atom}` tuple pointing to a
    `(msgid :: String.t(), bindings :: keyword) :: String.t()` typed function that will be called to translate
    each output text of the live view.
  * `gettext_backend` as a `{module :: module, domain :: String.t()}` tuple pointing to a Gettext backend module
    and specifying the Gettext domain. This is basically a convenience wrapper around `gettext_fn`.

  All other options are passed to the generated `scope`.
  """
  @spec confirm_route(
          resource :: Ash.Resource.t(),
          strategy :: atom(),
          opts :: [
            {:path, String.t()}
            | {:live_view, module}
            | {:as, atom}
            | {:overrides, [module]}
            | {:gettext_fn, {module, atom}}
            | {:gettext_backend, {module, String.t()}}
            | {:on_mount, [module]}
            | {:on_mount_prepend, [module]}
            | {atom, any}
          ]
        ) :: Macro.t()
  defmacro confirm_route(resource, strategy, opts \\ []) do
    {path, opts} = Keyword.pop(opts, :path, "/#{strategy}")
    {live_view, opts} = Keyword.pop(opts, :live_view, AshAuthentication.Phoenix.ConfirmLive)
    {as, opts} = Keyword.pop(opts, :as, :auth)
    {otp_app, opts} = Keyword.pop(opts, :otp_app)
    {layout, opts} = Keyword.pop(opts, :layout)
    {on_mount, opts} = Keyword.pop(opts, :on_mount)
    {on_mount_prepend, opts} = Keyword.pop(opts, :on_mount_prepend)
    {auth_routes_prefix, opts} = Keyword.pop(opts, :auth_routes_prefix)
    {gettext_fn, opts} = Keyword.pop(opts, :gettext_fn)
    {gettext_backend, opts} = Keyword.pop(opts, :gettext_backend)

    {overrides, opts} =
      Keyword.pop(opts, :overrides, [AshAuthentication.Phoenix.Overrides.Default])

    gettext_fn =
      maybe_generate_gettext_fn_pointer(gettext_fn, gettext_backend, __CALLER__.module, path)

    opts =
      opts
      |> Keyword.put_new(:alias, false)

    quote do
      auth_routes_prefix =
        case unquote(auth_routes_prefix) do
          nil -> nil
          {:unscoped, value} -> value
          value -> Phoenix.Router.scoped_path(__MODULE__, value)
        end

      scope unquote(path), unquote(opts) do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        on_mount =
          (List.wrap(unquote(on_mount_prepend)) ++
             [
               AshAuthentication.Phoenix.Router.OnLiveViewMount,
               AshAuthentication.Phoenix.LiveSession | unquote(on_mount || [])
             ])
          |> Enum.uniq_by(fn
            {mod, _} -> mod
            mod -> mod
          end)

        live_session_opts = [
          session:
            {AshAuthentication.Phoenix.Router, :generate_session,
             [
               %{
                 "auth_routes_prefix" => auth_routes_prefix,
                 "overrides" => unquote(overrides),
                 "gettext_fn" => unquote(gettext_fn),
                 "resource" => unquote(resource),
                 "strategy" => unquote(strategy),
                 "otp_app" => unquote(otp_app)
               }
             ]},
          on_mount: on_mount
        ]

        live_session_opts =
          case unquote(layout) do
            nil ->
              live_session_opts

            layout ->
              Keyword.put(live_session_opts, :layout, layout)
          end

        live_session :"#{unquote(as)}_confirm", live_session_opts do
          if unquote(Keyword.get(opts, :token_as_route_param?, true)) do
            live("/:token", unquote(live_view), :confirm, as: unquote(as))
          else
            live("/", unquote(live_view), :confirm, as: unquote(as))
          end
        end
      end

      unquote(generate_gettext_fn(gettext_backend, path))
    end
  end

  @doc """
  Generates a genric, white-label magic link sign in page using LiveView and the components in `AshAuthentication.Phoenix.Components`.

  This is used when `require_interaction?` is set to `true` on a magic link strategy.

  Available options are:

  * `path` the path under which to mount the live-view. Defaults to
  * `auth_routes_prefix` if set, this will be used instead of route helpers when determining routes.
    Allows disabling `helpers: true`.
    If a tuple `{:unscoped, path}` is provided, the path prefix will not inherit the current route scope.
    "/<strategy>".
  * `token_as_route_param?` whether to use the token as a route parameter. i.e `<path>/:token`. Defaults to `true`.
  * `live_view` the name of the live view to render. Defaults to
    `AshAuthentication.Phoenix.MagicSignInLive`.
  * `as` which is passed to the generated `live` route. Defaults to `:auth`.
  * `overrides` specify any override modules for customisation. See
    `AshAuthentication.Phoenix.Overrides` for more information.
  * `gettext_fn` as a `{module :: module, function :: atom}` tuple pointing to a
    `(msgid :: String.t(), bindings :: keyword) :: String.t()` typed function that will be called to translate
    each output text of the live view.
  * `gettext_backend` as a `{module :: module, domain :: String.t()}` tuple pointing to a Gettext backend module
    and specifying the Gettext domain. This is basically a convenience wrapper around `gettext_fn`.

  All other options are passed to the generated `scope`.
  """
  @spec magic_sign_in_route(
          resource :: Ash.Resource.t(),
          strategy :: atom(),
          opts :: [
            {:path, String.t()}
            | {:live_view, module}
            | {:as, atom}
            | {:overrides, [module]}
            | {:gettext_fn, {module, atom}}
            | {:gettext_backend, {module, String.t()}}
            | {:on_mount, [module]}
            | {:on_mount_prepend, [module]}
            | {atom, any}
          ]
        ) :: Macro.t()
  defmacro magic_sign_in_route(resource, strategy, opts \\ []) do
    {path, opts} = Keyword.pop(opts, :path, "/#{strategy}")
    {live_view, opts} = Keyword.pop(opts, :live_view, AshAuthentication.Phoenix.MagicSignInLive)
    {as, opts} = Keyword.pop(opts, :as, :auth)
    {otp_app, opts} = Keyword.pop(opts, :otp_app)
    {layout, opts} = Keyword.pop(opts, :layout)
    {on_mount, opts} = Keyword.pop(opts, :on_mount)
    {on_mount_prepend, opts} = Keyword.pop(opts, :on_mount_prepend)
    {auth_routes_prefix, opts} = Keyword.pop(opts, :auth_routes_prefix)
    {gettext_fn, opts} = Keyword.pop(opts, :gettext_fn)
    {gettext_backend, opts} = Keyword.pop(opts, :gettext_backend)

    {overrides, opts} =
      Keyword.pop(opts, :overrides, [AshAuthentication.Phoenix.Overrides.Default])

    gettext_fn =
      maybe_generate_gettext_fn_pointer(gettext_fn, gettext_backend, __CALLER__.module, path)

    opts =
      opts
      |> Keyword.put_new(:alias, false)

    quote do
      auth_routes_prefix =
        case unquote(auth_routes_prefix) do
          nil -> nil
          {:unscoped, value} -> value
          value -> Phoenix.Router.scoped_path(__MODULE__, value)
        end

      scope unquote(path), unquote(opts) do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        on_mount =
          (List.wrap(unquote(on_mount_prepend)) ++
             [
               AshAuthentication.Phoenix.Router.OnLiveViewMount,
               AshAuthentication.Phoenix.LiveSession | unquote(on_mount || [])
             ])
          |> Enum.uniq_by(fn
            {mod, _} -> mod
            mod -> mod
          end)

        live_session_opts = [
          session:
            {AshAuthentication.Phoenix.Router, :generate_session,
             [
               %{
                 "auth_routes_prefix" => auth_routes_prefix,
                 "overrides" => unquote(overrides),
                 "gettext_fn" => unquote(gettext_fn),
                 "resource" => unquote(resource),
                 "strategy" => unquote(strategy),
                 "otp_app" => unquote(otp_app)
               }
             ]},
          on_mount: on_mount
        ]

        live_session_opts =
          case unquote(layout) do
            nil ->
              live_session_opts

            layout ->
              Keyword.put(live_session_opts, :layout, layout)
          end

        live_session :"#{unquote(as)}_magic_sign_in", live_session_opts do
          if unquote(Keyword.get(opts, :token_as_route_param?, true)) do
            live("/:token", unquote(live_view), :sign_in, as: unquote(as))
          else
            live("/", unquote(live_view), :sign_in, as: unquote(as))
          end
        end
      end

      unquote(generate_gettext_fn(gettext_backend, path))
    end
  end

  @doc false
  def generate_session(conn, session) do
    session
    |> Map.put("tenant", Ash.PlugHelpers.get_tenant(conn))
    |> Map.put("context", Ash.PlugHelpers.get_context(conn))
  end

  # When using a `gettext_backend`, we generate a function in the caller's router module, involving the
  # path as unique id for the function name
  defp generate_gettext_fn(nil, _id), do: ""

  defp generate_gettext_fn({module, domain}, id) do
    if Code.ensure_loaded?(Gettext) do
      quote do
        # sobelow_skip ["DOS.BinToAtom"] - based on auth route
        def unquote(:"__translate#{id}")(msgid, bindings) do
          Gettext.dgettext(unquote(module), unquote(domain), msgid, bindings)
        end
      end
    else
      raise "gettext_backend: Gettext is not available"
    end
  end

  defp maybe_generate_gettext_fn_pointer(nil, nil, _router_module, _id), do: nil

  # Prefer gettext_fn over gettext_backend
  defp maybe_generate_gettext_fn_pointer(gettext_fn, _ignore, _router_module, _id)
       when is_tuple(gettext_fn),
       do: gettext_fn

  # Point to the "translate" function generated by `generate_gettext_fn`
  defp maybe_generate_gettext_fn_pointer(_gettext_fn, {_module, _domain}, router_module, id),
    # sobelow_skip ["DOS.BinToAtom"] - based on auth route
    do: {router_module, :"__translate#{id}"}

  defp maybe_generate_gettext_fn_pointer(_gettext_fn, invalid, _router_module, _id) do
    raise ArgumentError,
          "gettext_backend: #{inspect(invalid)} is invalid - specify " <>
            "`{module :: module, domain :: String.t()}`"
  end
end
