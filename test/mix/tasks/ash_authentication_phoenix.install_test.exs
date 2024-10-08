# credo:disable-for-this-file Credo.Check.Design.AliasUsage
defmodule Mix.Tasks.AshAuthenticationPhoenix.InstallTest do
  use ExUnit.Case

  import Igniter.Test

  setup do
    igniter =
      test_project()
      |> Igniter.Project.Deps.add_dep({:simple_sat, ">= 0.0.0"})
      |> Igniter.Project.Deps.add_dep({:ash_authentication, ">= 0.0.0"})
      |> Igniter.Project.Formatter.add_formatter_plugin(Spark.Formatter)
      |> Igniter.compose_task("ash_authentication.install")
      |> Igniter.Project.Module.create_module(TestWeb.Router, """
      @moduledoc false

      use TestWeb, :router

      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_live_flash
        plug :put_root_layout, {DevWeb.LayoutView, :root}
        plug :protect_from_forgery
        plug :put_secure_browser_headers
      end

      pipeline :api do
        plug :accepts, ["json"]
      end
      """)
      |> apply_igniter!()

    [igniter: igniter]
  end

  test "installation modifies the .formatter.exs", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("ash_authentication_phoenix.install")
    |> assert_has_patch(".formatter.exs", """
      5   - |  import_deps: [:ash_authentication]
        5 + |  import_deps: [:ash_authentication_phoenix, :ash_authentication]
    """)
  end

  test "installation adds the phoenix igniter extension", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("ash_authentication_phoenix.install")
    |> assert_has_patch(".igniter.exs", """
     6    - |  extensions: [],
        6 + |  extensions: [{Igniter.Extensions.Phoenix, []}],
    """)
  end

  test "installation creates an overrides module", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("ash_authentication_phoenix.install")
    |> assert_creates("lib/test_web/auth_overrides.ex", """
    defmodule TestWeb.AuthOverrides do
      use AshAuthentication.Phoenix.Overrides

      # configure your UI overrides here

      # First argument to `override` is the component name you are overriding.
      # The body contains any number of configurations you wish to override
      # Below are some examples

      # For a complete reference, see https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html

      # override AshAuthentication.Phoenix.Components.Banner do
      #   set :image_url, "https://media.giphy.com/media/g7GKcSzwQfugw/giphy.gif"
      #   set :text_class, "bg-red-500"
      # end

      # override AshAuthentication.Phoenix.Components.SignIn do
      #  set :show_banner false
      # end
    end
    """)
  end

  test "installation creates an auth controller", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("ash_authentication_phoenix.install")
    |> assert_creates("lib/test_web/controllers/auth_controller.ex", """
    defmodule TestWeb.AuthController do
      use TestWeb, :controller
      use AshAuthentication.Phoenix.Controller

      def success(conn, _activity, user, _token) do
        return_to = get_session(conn, :return_to) || ~p"/"

        conn
        |> delete_session(:return_to)
        |> store_in_session(user)
        # If your resource has a different name, update the assign name here (i.e :current_admin)
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
    """)
  end

  test "installation creates a live user auth hook module", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("ash_authentication_phoenix.install")
    |> assert_creates("lib/test_web/live_user_auth.ex", """
    defmodule TestWeb.LiveUserAuth do
      @moduledoc \"\"\"
      Helpers for authenticating users in LiveViews.
      \"\"\"

      import Phoenix.Component
      use TestWeb, :verified_routes

      def on_mount(:live_user_optional, _params, _session, socket) do
        if socket.assigns[:current_user] do
          {:cont, socket}
        else
          {:cont, assign(socket, :current_user, nil)}
        end
      end

      def on_mount(:live_user_required, _params, _session, socket) do
        if socket.assigns[:current_user] do
          {:cont, socket}
        else
          {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
        end
      end

      def on_mount(:live_no_user, _params, _session, socket) do
        if socket.assigns[:current_user] do
          {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
        else
          {:cont, assign(socket, :current_user, nil)}
        end
      end
    end
    """)
  end

  test "installation modifies the router", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("ash_authentication_phoenix.install")
    |> assert_has_patch("lib/test_web/router.ex", """
    6 + |  use AshAuthentication.Phoenix.Router
    """)
    |> assert_has_patch("lib/test_web/router.ex", """
    15 + |    plug(:load_from_session)
    """)
    |> assert_has_patch("lib/test_web/router.ex", """
    15 18   |  pipeline :api do
    16 19   |    plug(:accepts, ["json"])
       20 + |    plug(:load_from_bearer)
    17 21   |  end
    """)
    |> assert_has_patch("lib/test_web/router.ex", """
    23 + |  scope "/", TestWeb do
    24 + |    ash_authentication_live_session :authentication_required,
    25 + |      on_mount: {TestWeb.LiveUserAuth, :live_user_required} do
    26 + |      # Put live routes that require a user to be logged in here
    27 + |    end
    28 + |
    29 + |    ash_authentication_live_session :authentication_optional,
    30 + |      on_mount: {TestWeb.LiveUserAuth, :live_user_optional} do
    31 + |      # Put live routes that allow a user to be logged in *or* logged out here
    32 + |    end
    33 + |
    34 + |    ash_authentication_live_session :authentication_rejected,
    35 + |      on_mount: {TestWeb.LiveUserAuth, :live_no_user} do
    36 + |      # Put live routes that a user who is logged in should never see here
    37 + |    end
    38 + |  end
    39 + |
    40 + |  scope "/", TestWeb do
    41 + |    pipe_through([:browser])
    42 + |    auth_routes(AuthController, Test.Accounts.User, path: "/auth")
    43 + |    sign_out_route(AuthController)
    44 + |
    45 + |    # Remove these if you'd like to use your own authentication views
    46 + |    sign_in_route(
    47 + |      register_path: "/register",
    48 + |      reset_path: "/reset",
    49 + |      auth_routes_prefix: "/auth",
    50 + |      on_mount: [{TestWeb.LiveUserAuth, :live_no_user}],
    51 + |      overrides: [TestWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    52 + |    )
    53 + |
    54 + |    # Remove this if you do not want to use the reset password feature
    55 + |    reset_route(auth_routes_prefix: "/auth")
    56 + |  end
    """)
  end
end
