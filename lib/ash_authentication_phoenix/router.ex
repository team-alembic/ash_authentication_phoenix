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
      auth_routes_for MyApp.Accounts.User, to: AuthController
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
            match :*,
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

      scope "/", alias: false do
        forward path, AshAuthentication.Phoenix.StrategyRouter,
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

  * `path` the path under which to mount the sign-in live-view. Defaults to `"/sign-in"` within the current router scope.
  * `auth_routes_prefix` if set, this will be used instead of route helpers when determining routes.
    Allows disabling `helpers: true`.
    If a tuple {:unscoped, path} is provided, the path prefix will not inherit the current route scope.
  * `register_path` - the path under which to mount the password strategy's registration live-view.
     If not set, and registration is supported, registration will use a dynamic toggle and will not be routeable to.
     If a tuple {:unscoped, path} is provided, the registration path will not inherit the current route scope.
  * `reset_path` - the path under which to mount the password strategy's password reset live-view.
    If not set, and password reset is supported, password reset will use a dynamic toggle and will not be routeable to.
    If a tuple {:unscoped, path} is provided, the reset path will not inherit the current route scope.
  * `live_view` the name of the live view to render. Defaults to
    `AshAuthentication.Phoenix.SignInLive`.
  * `auth_routes_prefix` the prefix to use for the auth routes. Defaults to `"/auth"`.
  * `as` which is used to prefix the generated `live_session` and `live` route name. Defaults to `:auth`.
  * `otp_app` the otp app or apps to find authentication resources in. Pulls from the socket by default.
  * `overrides` specify any override modules for customisation.  See
    `AshAuthentication.Phoenix.Overrides` for more information.

    all other options are passed to the generated `scope`.
  """
  @spec sign_in_route(
          opts :: [
            {:path, String.t()}
            | {:live_view, module}
            | {:as, atom}
            | {:overrides, [module]}
            | {:on_mount, [module]}
            | {atom, any}
          ]
        ) :: Macro.t()
  defmacro sign_in_route(opts \\ []) do
    {path, opts} = Keyword.pop(opts, :path, "/sign-in")
    {live_view, opts} = Keyword.pop(opts, :live_view, AshAuthentication.Phoenix.SignInLive)
    {as, opts} = Keyword.pop(opts, :as, :auth)
    {otp_app, opts} = Keyword.pop(opts, :otp_app)
    {layout, opts} = Keyword.pop(opts, :layout)
    {on_mount, opts} = Keyword.pop(opts, :on_mount)
    {reset_path, opts} = Keyword.pop(opts, :reset_path)
    {register_path, opts} = Keyword.pop(opts, :register_path)
    {auth_routes_prefix, opts} = Keyword.pop(opts, :auth_routes_prefix)

    {overrides, opts} =
      Keyword.pop(opts, :overrides, [AshAuthentication.Phoenix.Overrides.Default])

    opts =
      opts
      |> Keyword.put_new(:alias, false)

    quote do
      scope "/", unquote(opts) do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        on_mount =
          [
            AshAuthentication.Phoenix.Router.OnLiveViewMount,
            AshAuthentication.Phoenix.LiveSession | unquote(on_mount || [])
          ]
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
                 "path" => sign_in_path,
                 "reset_path" => reset_path,
                 "register_path" => register_path
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
  Generates a generic, white-label password reset page using LiveView and the
  components in `AshAuthentication.Phoenix.Components`.

  Available options are:

    * `path` the path under which to mount the live-view. Defaults to
      `"/password-reset"`.
    * `live_view` the name of the live view to render. Defaults to
      `AshAuthentication.Phoenix.ResetLive`.
    * `as` which is passed to the generated `live` route. Defaults to `:auth`.
    * `overrides` specify any override modules for customisation.  See
      `AshAuthentication.Phoenix.Overrides` for more information. all other
      options are passed to the generated `scope`.

  This is completely optional, in particular, if the `reset_path` option is passed to the
  `sign_in_route` helper, using the `reset_route` helper is redundant.
  """
  @spec reset_route(
          opts :: [
            {:path, String.t()}
            | {:live_view, module}
            | {:as, atom}
            | {:overrides, [module]}
            | {:on_mount, [module]}
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
    {auth_routes_prefix, opts} = Keyword.pop(opts, :auth_routes_prefix)

    {overrides, opts} =
      Keyword.pop(opts, :overrides, [AshAuthentication.Phoenix.Overrides.Default])

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
          [
            AshAuthentication.Phoenix.Router.OnLiveViewMount,
            AshAuthentication.Phoenix.LiveSession | unquote(on_mount || [])
          ]
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
    end
  end

  @doc false
  def generate_session(conn, session) do
    session
    |> Map.put("tenant", Ash.PlugHelpers.get_tenant(conn))
    |> Map.put("context", Ash.PlugHelpers.get_context(conn))
  end
end
