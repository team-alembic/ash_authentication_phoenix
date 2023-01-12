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
      sign_in_route
      sign_out_route AuthController
      auth_routes_for MyApp.Accounts.User, to: AuthController
      reset_route
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
      scope_opts = Keyword.get(unquote(opts), :scope_opts, [])

      strategies =
        AshAuthentication.Info.authentication_add_ons(unquote(resource)) ++
          AshAuthentication.Info.authentication_strategies(unquote(resource))

      scope path, scope_opts do
        for strategy <- strategies do
          for {path, phase} <- AshAuthentication.Strategy.routes(strategy) do
            match :*, path, controller, {subject_name, strategy.name, phase},
              as: :auth,
              private: %{strategy: strategy}
          end
        end
      end
    end
  end

  @doc """
  Generates a generic, white-label sign-in page using LiveView and the
  components in `AshAuthentication.Phoenix.Components`.

  This is completely optional.

  Available options are:

  * `path` the path under which to mount the live-view. Defaults to
    `"/sign-in"`.
  * `live_view` the name of the live view to render. Defaults to
    `AshAuthentication.Phoenix.SignInLive`.
  * `as` which is passed to the generated `live` route. Defaults to `:auth`.
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
            | {atom, any}
          ]
        ) :: Macro.t()
  defmacro sign_in_route(opts \\ []) do
    {path, opts} = Keyword.pop(opts, :path, "/sign-in")
    {live_view, opts} = Keyword.pop(opts, :live_view, AshAuthentication.Phoenix.SignInLive)
    {as, opts} = Keyword.pop(opts, :as, :auth)

    {overrides, opts} =
      Keyword.pop(opts, :overrides, [AshAuthentication.Phoenix.Overrides.Default])

    opts =
      opts
      |> Keyword.put_new(:alias, false)

    quote do
      scope unquote(path), unquote(opts) do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        live_session :sign_in, session: %{"overrides" => unquote(overrides)} do
          live("/", unquote(live_view), :sign_in, as: unquote(as))
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

  This is completely optional.
  """
  @spec reset_route(
          opts :: [
            {:path, String.t()}
            | {:live_view, module}
            | {:as, atom}
            | {:overrides, [module]}
            | {atom, any}
          ]
        ) :: Macro.t()
  defmacro reset_route(opts \\ []) do
    {path, opts} = Keyword.pop(opts, :path, "/password-reset")
    {live_view, opts} = Keyword.pop(opts, :live_view, AshAuthentication.Phoenix.ResetLive)
    {as, opts} = Keyword.pop(opts, :as, :auth)

    {overrides, opts} =
      Keyword.pop(opts, :overrides, [AshAuthentication.Phoenix.Overrides.Default])

    opts =
      opts
      |> Keyword.put_new(:alias, false)

    quote do
      scope unquote(path), unquote(opts) do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 2]

        live_session :reset do
          live("/:token", unquote(live_view), :reset,
            as: unquote(as),
            private: %{overrides: unquote(overrides)}
          )
        end
      end
    end
  end
end
