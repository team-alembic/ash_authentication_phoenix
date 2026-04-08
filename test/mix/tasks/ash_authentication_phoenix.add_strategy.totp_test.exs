# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy.TotpTest do
  use ExUnit.Case

  import Igniter.Test

  @moduletag :igniter

  setup do
    igniter =
      test_project()
      |> Igniter.Project.Deps.add_dep({:simple_sat, ">= 0.0.0"})
      |> Igniter.Project.Deps.add_dep({:ash_authentication, ">= 0.0.0"})
      |> Igniter.Project.Formatter.add_formatter_plugin(Spark.Formatter)
      |> Igniter.compose_task("ash_authentication.install", ["--yes"])
      |> Igniter.Project.Module.create_module(TestWeb.Router, """
      @moduledoc false

      use TestWeb, :router

      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
      end

      scope "/", TestWeb do
        pipe_through :browser
      end
      """)
      |> Igniter.Project.Module.create_module(TestWeb.AuthController, """
      use TestWeb, :controller
      use AshAuthentication.Phoenix.Controller

      def success(conn, activity, user, token) do
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
        |> set_live_socket_id(token)
        |> assign(:current_user, user)
        |> put_flash(:info, message)
        |> redirect(to: return_to)
      end

      def failure(conn, _activity, _reason) do
        conn
        |> put_flash(:error, "Incorrect email or password")
        |> redirect(to: ~p"/sign-in")
      end

      def sign_out(conn, _params) do
        conn
        |> redirect(to: ~p"/")
      end
      """)
      |> apply_igniter!()

    [igniter: igniter]
  end

  describe "2fa mode" do
    test "inserts sign-in interception clause before existing success/4", %{
      igniter: igniter
    } do
      igniter
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.totp", ["--mode", "2fa"])
      |> assert_has_patch("lib/test_web/auth_controller.ex", """
      + |  def success(conn, {_, phase} = _activity, user, token)
      + |      when phase in [:sign_in, :sign_in_with_token] do
      """)
    end

    test "sign-in clause stores user in session before redirecting to verify", %{
      igniter: igniter
    } do
      result =
        igniter
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.totp", ["--mode", "2fa"])

      controller_diff = diff(result, path: "lib/test_web/auth_controller.ex")
      assert controller_diff =~ "store_in_session(user)"
      assert controller_diff =~ "totp-verify"
    end

    test "inserts registration redirect clause before existing success/4", %{
      igniter: igniter
    } do
      igniter
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.totp", ["--mode", "2fa"])
      |> assert_has_patch("lib/test_web/auth_controller.ex", """
      + |  def success(conn, {_, :register}, user, token) do
      """)
    end

    test "does not modify the existing catch-all success clause", %{igniter: igniter} do
      result =
        igniter
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.totp", ["--mode", "2fa"])

      refute diff(result, path: "lib/test_web/auth_controller.ex") =~ "- |  def success"
    end

    test "adds totp_2fa_route and totp_setup_route to the router", %{igniter: igniter} do
      igniter
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.totp", ["--mode", "2fa"])
      |> assert_has_patch("lib/test_web/router.ex", """
      + |    totp_2fa_route(Test.Accounts.User, :totp,
      + |      auth_routes_prefix: "/auth",
      + |      overrides: [TestWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
      + |    )
      """)
      |> assert_has_patch("lib/test_web/router.ex", """
      + |    totp_setup_route(Test.Accounts.User, :totp,
      + |      auth_routes_prefix: "/auth",
      + |      overrides: [TestWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
      + |    )
      """)
    end

    test "is idempotent", %{igniter: igniter} do
      igniter =
        igniter
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.totp", ["--mode", "2fa"])
        |> apply_igniter!()

      igniter
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.totp", ["--mode", "2fa"])
      |> assert_unchanged("lib/test_web/auth_controller.ex")
    end
  end

  describe "primary mode" do
    test "does not modify controller", %{igniter: igniter} do
      igniter
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.totp", [
        "--mode",
        "primary"
      ])
      |> assert_unchanged("lib/test_web/auth_controller.ex")
    end

    test "adds only totp_setup_route to the router", %{igniter: igniter} do
      result =
        igniter
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.totp", [
          "--mode",
          "primary"
        ])

      assert_has_patch(result, "lib/test_web/router.ex", """
      + |    totp_setup_route(Test.Accounts.User, :totp,
      + |      auth_routes_prefix: "/auth",
      + |      overrides: [TestWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
      + |    )
      """)

      refute diff(result, path: "lib/test_web/router.ex") =~ "totp_2fa_route"
    end
  end

  describe "missing controller" do
    test "emits warning when controller does not exist" do
      igniter =
        test_project()
        |> Igniter.Project.Deps.add_dep({:simple_sat, ">= 0.0.0"})
        |> Igniter.Project.Deps.add_dep({:ash_authentication, ">= 0.0.0"})
        |> Igniter.Project.Formatter.add_formatter_plugin(Spark.Formatter)
        |> Igniter.compose_task("ash_authentication.install", ["--yes"])
        |> apply_igniter!()

      igniter
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.totp", ["--mode", "2fa"])
      |> assert_has_warning(&String.contains?(&1, "Could not find AuthController"))
    end
  end
end
