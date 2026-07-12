# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

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

  test "3.0.0: creates a scope module and swaps set_actor for set_scope" do
    test_project()
    |> Igniter.Project.Module.create_module(TestWeb.Router, """
    use TestWeb, :router
    use AshAuthentication.Phoenix.Router

    pipeline :browser do
      plug :accepts, ["html"]
      plug :load_from_session
      plug :set_actor, :user
    end

    pipeline :api do
      plug :accepts, ["json"]
      plug :load_from_bearer
      plug :set_actor, :user
    end
    """)
    |> Igniter.compose_task("ash_authentication_phoenix.upgrade", ["3.0.0-rc.8", "3.0.0"])
    |> assert_creates("lib/test_web/router.ex", """
    defmodule TestWeb.Router do
      use TestWeb, :router
      use AshAuthentication.Phoenix.Router

      pipeline :browser do
        plug(:accepts, ["html"])
        plug(:load_from_session)
        plug(:set_scope, scope: Test.Accounts.Scope, default_scope?: true)
      end

      pipeline :api do
        plug(:accepts, ["json"])
        plug(:load_from_bearer)
        plug(:set_scope, scope: Test.Accounts.Scope, default_scope?: true)
      end
    end
    """)
    |> assert_creates("lib/test/accounts/scope.ex", """
    defmodule Test.Accounts.Scope do
      @moduledoc \"\"\"
      Authentication scope.

      Wraps the current actor and tenant in a single struct that implements
      `Ash.Scope.ToOpts`, so it can be passed to any Ash action as `scope:`:

          Ash.read!(query, scope: socket.assigns.current_user_scope)

      Grow this struct as your application does — add organisation, permissions,
      locale, and so on — and expose them through the `ToOpts` callbacks below.
      \"\"\"

      defstruct [:actor, :tenant]

      defimpl Ash.Scope.ToOpts, for: __MODULE__ do
        def get_actor(%{actor: actor}), do: {:ok, actor}
        def get_tenant(%{tenant: tenant}), do: {:ok, tenant}
        def get_context(_scope), do: :error
        def get_tracer(_scope), do: :error
        def get_authorize?(_scope), do: :error
      end
    end
    """)
  end

  test "3.0.0: leaves an already-migrated router's plugs unchanged" do
    test_project()
    |> Igniter.Project.Module.create_module(TestWeb.Router, """
    use TestWeb, :router
    use AshAuthentication.Phoenix.Router

    pipeline :browser do
      plug :accepts, ["html"]
      plug :load_from_session
      plug :set_scope, scope: Test.Accounts.Scope, default_scope?: true
    end
    """)
    |> Igniter.compose_task("ash_authentication_phoenix.upgrade", ["3.0.0-rc.8", "3.0.0"])
    |> assert_creates("lib/test_web/router.ex", """
    defmodule TestWeb.Router do
      use TestWeb, :router
      use AshAuthentication.Phoenix.Router

      pipeline :browser do
        plug(:accepts, ["html"])
        plug(:load_from_session)
        plug(:set_scope, scope: Test.Accounts.Scope, default_scope?: true)
      end
    end
    """)
  end

  test "3.0.0: adds scope options to an option-less ash_authentication_live_session" do
    test_project()
    |> Igniter.Project.Module.create_module(TestWeb.Router, """
    use TestWeb, :router
    use AshAuthentication.Phoenix.Router

    scope "/", TestWeb do
      ash_authentication_live_session :authenticated_routes do
        live "/", HomeLive
      end
    end
    """)
    |> Igniter.compose_task("ash_authentication_phoenix.upgrade", ["3.0.0-rc.8", "3.0.0"])
    |> assert_creates("lib/test_web/router.ex", """
    defmodule TestWeb.Router do
      use TestWeb, :router
      use AshAuthentication.Phoenix.Router

      scope "/", TestWeb do
        ash_authentication_live_session :authenticated_routes,
          scope: Test.Accounts.Scope,
          default_scope: :user do
          live("/", HomeLive)
        end
      end
    end
    """)
  end

  test "3.0.0: leaves an ash_authentication_live_session that already has options alone" do
    test_project()
    |> Igniter.Project.Module.create_module(TestWeb.Router, """
    use TestWeb, :router
    use AshAuthentication.Phoenix.Router

    scope "/", TestWeb do
      ash_authentication_live_session :authenticated_routes, on_mount: [SomeHook] do
        live "/", HomeLive
      end
    end
    """)
    |> Igniter.compose_task("ash_authentication_phoenix.upgrade", ["3.0.0-rc.8", "3.0.0"])
    |> assert_creates("lib/test_web/router.ex", """
    defmodule TestWeb.Router do
      use TestWeb, :router
      use AshAuthentication.Phoenix.Router

      scope "/", TestWeb do
        ash_authentication_live_session :authenticated_routes, on_mount: [SomeHook] do
          live("/", HomeLive)
        end
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
