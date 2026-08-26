# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
defmodule Mix.Tasks.AshAuthenticationPhoenix.InstallRouterNamespaceTest do
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
      |> Igniter.Project.Module.create_module(Test.Admin.Web.Router, """
      @moduledoc false

      use Test.Admin.Web, :router

      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_live_flash
        plug :put_root_layout, {Test.Admin.Web.LayoutView, :root}
        plug :protect_from_forgery
        plug :put_secure_browser_headers
      end

      pipeline :api do
        plug :accepts, ["json"]
      end
      """)
      |> apply_igniter!()
      |> Igniter.compose_task("ash_authentication_phoenix.install")

    [igniter: igniter]
  end

  test "the overrides module is created under the router's web module", %{igniter: igniter} do
    igniter
    |> refute_creates("lib/test_web/auth_overrides.ex")
    |> assert_has_patch("lib/test/admin/web/auth_overrides.ex", """
    |defmodule Test.Admin.Web.AuthOverrides do
    """)
  end

  test "the auth controller is created under the router's web module", %{igniter: igniter} do
    igniter
    |> refute_creates("lib/test_web/controllers/auth_controller.ex")
    |> assert_has_patch("lib/test/admin/web/auth_controller.ex", """
    |defmodule Test.Admin.Web.AuthController do
    |  use Test.Admin.Web, :controller
    """)
  end

  test "the live user auth module is created under the router's web module", %{igniter: igniter} do
    igniter
    |> refute_creates("lib/test_web/live_user_auth.ex")
    |> assert_has_patch("lib/test/admin/web/live_user_auth.ex", """
    |defmodule Test.Admin.Web.LiveUserAuth do
    """)
    |> assert_has_patch("lib/test/admin/web/live_user_auth.ex", """
    |  use Test.Admin.Web, :verified_routes
    """)
  end

  test "the generated routes are scoped and namespaced against the router's web module", %{
    igniter: igniter
  } do
    igniter
    |> assert_has_patch("lib/test/admin/web/router.ex", """
    + |  scope "/", Test.Admin.Web do
    """)
    |> assert_has_patch("lib/test/admin/web/router.ex", """
    + |      on_mount: [{Test.Admin.Web.LiveUserAuth, :live_no_user}],
    """)
    |> assert_has_patch("lib/test/admin/web/router.ex", """
    + |      overrides: [Test.Admin.Web.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    """)
  end

  test "the token resource is pointed at the router's endpoint", %{igniter: igniter} do
    assert_has_patch(igniter, "lib/test/accounts/token.ex", """
    + |    endpoints [Test.Admin.Web.Endpoint]
    """)
  end

  test "installation is idempotent", %{igniter: igniter} do
    igniter
    |> apply_igniter!()
    |> Igniter.compose_task("ash_authentication_phoenix.install")
    |> assert_unchanged()
  end
end
