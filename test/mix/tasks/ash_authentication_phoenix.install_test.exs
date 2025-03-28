# credo:disable-for-this-file Credo.Check.Design.AliasUsage
defmodule Mix.Tasks.AshAuthenticationPhoenix.InstallTest do
  use ExUnit.Case
  @moduletag :igniter

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
      #  set :show_banner, false
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

      def success(conn, activity, user, _token) do
        return_to = get_session(conn, :return_to) || ~p"/"

        message =
          case activity do
            {:confirm_new_user, :confirm} -> "Your email address has now been confirmed"
            {:password, :reset} -> "Your password has successfully been reset"
            _ -> "You are now signed in"
          end

        conn
        |> delete_session(:return_to)
        |> store_in_session(user)
        # If your resource has a different name, update the assign name here (i.e :current_admin)
        |> assign(:current_user, user)
        |> put_flash(:info, message)
        |> redirect(to: return_to)
      end

      def failure(conn, activity, reason) do
        message =
          case {activity, reason} do
            {_,
             %AshAuthentication.Errors.AuthenticationFailed{
               caused_by: %Ash.Error.Forbidden{
                 errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
               }
             }} ->
              \"\"\"
              You have already signed in another way, but have not confirmed your account.
              You can confirm your account using the link we sent to you, or by resetting your password.
              \"\"\"

            _ ->
              "Incorrect email or password"
          end

        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/sign-in")
      end

      def sign_out(conn, _params) do
        return_to = get_session(conn, :return_to) || ~p"/"

        conn
        |> clear_session()
        |> put_flash(:info, "You are now signed out")
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

      # This is used for nested liveviews to fetch the current user.
      # To use, place the following at the top of that liveview:
      # on_mount {TestWeb.LiveUserAuth, :current_user}
      def on_mount(:current_user, _params, session, socket) do
        {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
      end

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
    + |    plug(:load_from_session)
    """)
    |> assert_has_patch("lib/test_web/router.ex", """
      |  pipeline :api do
      |    plug(:accepts, ["json"])
    + |    plug(:load_from_bearer)
    + |    plug(:set_actor, :user)
      |  end
    """)
    |> assert_has_patch("lib/test_web/router.ex", """
    + |  scope "/", TestWeb do
    + |    pipe_through(:browser)
    + |
    + |    ash_authentication_live_session :authenticated_routes do
    + |      # in each liveview, add one of the following at the top of the module:
    + |      #
    + |      # If an authenticated user must be present:
    + |      # on_mount {TestWeb.LiveUserAuth, :live_user_required}
    + |      #
    + |      # If an authenticated user *may* be present:
    + |      # on_mount {TestWeb.LiveUserAuth, :live_user_optional}
    + |      #
    + |      # If an authenticated user must *not* be present:
    + |      # on_mount {TestWeb.LiveUserAuth, :live_no_user}
    + |    end
    + |  end
    + |
    + |  scope "/", TestWeb do
    + |    pipe_through([:browser])
    + |    auth_routes(AuthController, Test.Accounts.User, path: "/auth")
    + |    sign_out_route(AuthController)
    + |
    + |    # Remove these if you'd like to use your own authentication views
    + |    sign_in_route(
    + |      register_path: "/register",
    + |      reset_path: "/reset",
    + |      auth_routes_prefix: "/auth",
    + |      on_mount: [{TestWeb.LiveUserAuth, :live_no_user}],
    + |      overrides: [TestWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    + |    )
    + |
    + |    # Remove this if you do not want to use the reset password feature
    + |    reset_route(
    + |      auth_routes_prefix: "/auth",
    + |      overrides: [TestWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    + |    )
    + |  end
    """)
  end
end
