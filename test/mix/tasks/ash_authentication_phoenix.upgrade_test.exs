defmodule Mix.Tasks.AshAuthenticationPhoenix.UpgradeTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  test "transforms auth_routes_for to auth_routes in router" do
    test_project()
    |> Igniter.Project.Module.create_module(MyAppWeb.Router, """
    use MyAppWeb, :router
    use AshAuthentication.Phoenix.Router

    pipeline :browser do
      plug :accepts, ["html"]
      plug :load_from_session
    end

    scope "/", MyAppWeb do
      pipe_through :browser
      
      auth_routes_for MyApp.Accounts.User, to: AuthController, path: "/auth"
      auth_routes_for MyApp.Admin.User, to: AdminController
    end
    """)
    |> Igniter.compose_task("ash_authentication_phoenix.upgrade", ["2.10.5", "2.10.6"])
    |> assert_creates("lib/my_app_web/router.ex", """
    defmodule MyAppWeb.Router do
      use MyAppWeb, :router
      use AshAuthentication.Phoenix.Router

      pipeline :browser do
        plug(:accepts, ["html"])
        plug(:load_from_session)
      end

      scope "/", MyAppWeb do
        pipe_through(:browser)

        auth_routes(AuthController, MyApp.Accounts.User, path: "/auth")
        auth_routes(AdminController, MyApp.Admin.User)
      end
    end
    """)
  end

  test "handles router without auth_routes_for calls" do
    test_project()
    |> Igniter.Project.Module.create_module(MyAppWeb.Router, """
    use MyAppWeb, :router

    pipeline :browser do
      plug :accepts, ["html"]
    end

    scope "/", MyAppWeb do
      pipe_through :browser
      get "/", PageController, :home
    end
    """)
    |> Igniter.compose_task("ash_authentication_phoenix.upgrade", ["2.10.5", "2.10.6"])
    |> assert_creates("lib/my_app_web/router.ex", """
    defmodule MyAppWeb.Router do
      use MyAppWeb, :router

      pipeline :browser do
        plug(:accepts, ["html"])
      end

      scope "/", MyAppWeb do
        pipe_through(:browser)
        get("/", PageController, :home)
      end
    end
    """)
  end

  test "handles multiple routers" do
    test_project()
    |> Igniter.Project.Module.create_module(MyAppWeb.Router, """
    use MyAppWeb, :router
    use AshAuthentication.Phoenix.Router

    scope "/", MyAppWeb do
      auth_routes_for MyApp.Accounts.User, to: AuthController
    end
    """)
    |> Igniter.Project.Module.create_module(MyAppWeb.AdminRouter, """
    use MyAppWeb, :router
    use AshAuthentication.Phoenix.Router

    scope "/admin", MyAppWeb do
      auth_routes_for MyApp.Admin.User, to: AdminAuthController, path: "/auth"
    end
    """)
    |> Igniter.compose_task("ash_authentication_phoenix.upgrade", ["2.10.5", "2.10.6"])
    |> assert_creates("lib/my_app_web/router.ex", """
    defmodule MyAppWeb.Router do
      use MyAppWeb, :router
      use AshAuthentication.Phoenix.Router

      scope "/", MyAppWeb do
        auth_routes(AuthController, MyApp.Accounts.User)
      end
    end
    """)
    |> assert_creates("lib/my_app_web/admin_router.ex", """
    defmodule MyAppWeb.AdminRouter do
      use MyAppWeb, :router
      use AshAuthentication.Phoenix.Router

      scope "/admin", MyAppWeb do
        auth_routes(AdminAuthController, MyApp.Admin.User, path: "/auth")
      end
    end
    """)
  end
end
