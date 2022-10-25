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
      auth_routes AuthController
    end
  ```
  """

  require Logger

  @doc false
  @spec __using__(any) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      import AshAuthentication.Phoenix.Router
      import AshAuthentication.Phoenix.Plug
    end
  end

  @doc """
  Generates the routes needed for the various subjects and providers
  authenticating with AshAuthentication.

  This is required if you wish to use authentication.
  """
  defmacro auth_routes(auth_controller, path \\ "auth", opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:as, :auth)

    quote do
      scope unquote(path), unquote(opts) do
        match(:*, "/:subject_name/:provider", unquote(auth_controller), :request, as: :request)

        match(:*, "/:subject_name/:provider/callback", unquote(auth_controller), :callback,
          as: :callback
        )
      end
    end
  end

  @doc """
  Generates a generic, white-label sign-in page using LiveView and the
  components in `AshAuthentication.Phoenix.Components`.

  This is completely optional.
  """
  defmacro sign_in_route(
             path \\ "/sign-in",
             live_view \\ AshAuthentication.Phoenix.SignInLive,
             opts \\ []
           ) do
    {as, opts} = Keyword.pop(opts, :as, :auth)

    opts =
      opts
      |> Keyword.put_new(:alias, false)

    quote do
      scope unquote(path), unquote(opts) do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 2]

        live_session :sign_in do
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
  defmacro sign_out_route(auth_controller, path \\ "/sign-out", opts \\ []) do
    {as, opts} = Keyword.pop(opts, :as, :auth)

    quote do
      scope unquote(path), unquote(opts) do
        get("/", unquote(auth_controller), :sign_out, as: unquote(as))
      end
    end
  end
end
