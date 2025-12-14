# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.RouterTest do
  @moduledoc false
  use ExUnit.Case

  test "sign_in_routes adds a route according to its scope" do
    route =
      AshAuthentication.Phoenix.Test.Router
      |> Phoenix.Router.routes()
      |> Enum.find(&(&1.path == "/sign-in"))

    {_, _, _, %{extra: %{session: session}}} = route.metadata.phoenix_live_view

    assert session ==
             {AshAuthentication.Phoenix.Router, :generate_session,
              [
                %{
                  "auth_routes_prefix" => "/auth",
                  "otp_app" => nil,
                  "overrides" => [AshAuthentication.Phoenix.Overrides.Default],
                  "path" => "/sign-in",
                  "register_path" => "/register",
                  "reset_path" => "/reset",
                  "gettext_fn" => nil,
                  "resources" => nil
                }
              ]}
  end

  test "sign_in_routes respects the inherited router scope" do
    route =
      AshAuthentication.Phoenix.Test.Router
      |> Phoenix.Router.routes()
      |> Enum.find(&(&1.path == "/nested/sign-in"))

    {_, _, _, %{extra: %{session: session}}} = route.metadata.phoenix_live_view

    assert session ==
             {AshAuthentication.Phoenix.Router, :generate_session,
              [
                %{
                  "auth_routes_prefix" => "/nested/auth",
                  "otp_app" => nil,
                  "overrides" => [AshAuthentication.Phoenix.Overrides.Default],
                  "path" => "/nested/sign-in",
                  "register_path" => "/nested/register",
                  "reset_path" => "/nested/reset",
                  "gettext_fn" => nil,
                  "resources" => nil
                }
              ]}
  end

  test "sign_in_routes respects unscoped" do
    route =
      AshAuthentication.Phoenix.Test.Router
      |> Phoenix.Router.routes()
      |> Enum.find(&(&1.path == "/unscoped/sign-in"))

    {_, _, _, %{extra: %{session: session}}} = route.metadata.phoenix_live_view

    assert session ==
             {AshAuthentication.Phoenix.Router, :generate_session,
              [
                %{
                  "auth_routes_prefix" => "/auth",
                  "otp_app" => nil,
                  "overrides" => [AshAuthentication.Phoenix.Overrides.Default],
                  "path" => "/unscoped/sign-in",
                  "register_path" => "/register",
                  "reset_path" => "/reset",
                  "gettext_fn" => nil,
                  "resources" => nil
                }
              ]}
  end

  describe "auth_routes filtering" do
    @endpoint AshAuthentication.Phoenix.Test.Endpoint

    setup do
      {:ok, conn: Phoenix.ConnTest.build_conn()}
    end

    defp route_exists?(conn, base_path, method, strategy_path) do
      path = "#{base_path}/user/#{strategy_path}"
      result = Phoenix.ConnTest.dispatch(conn, @endpoint, method, path, nil)
      result.status != 404
    rescue
      FunctionClauseError -> true
    end

    test "only option includes only specified strategies", %{conn: conn} do
      base = "/auth-only"

      # password and github are in :only list - routes should exist
      assert route_exists?(conn, base, :post, "password/sign_in")
      assert route_exists?(conn, base, :get, "github")

      # auth0, slack, twitch, magic_link are NOT in :only list - routes should not exist
      refute route_exists?(conn, base, :get, "auth0")
      refute route_exists?(conn, base, :get, "slack")
      refute route_exists?(conn, base, :get, "twitch")
      refute route_exists?(conn, base, :post, "magic_link/request")
    end

    test "except option excludes specified strategies", %{conn: conn} do
      base = "/auth-except"

      # password, github, magic_link are NOT in :except list - routes should exist
      assert route_exists?(conn, base, :post, "password/sign_in")
      assert route_exists?(conn, base, :get, "github")
      assert route_exists?(conn, base, :post, "magic_link/request")

      # auth0, slack, twitch are in :except list - routes should not exist
      refute route_exists?(conn, base, :get, "auth0")
      refute route_exists?(conn, base, :get, "slack")
      refute route_exists?(conn, base, :get, "twitch")
    end

    test "unfiltered auth_routes includes all strategies", %{conn: conn} do
      base = "/auth"

      # All strategies should be accessible
      assert route_exists?(conn, base, :post, "password/sign_in")
      assert route_exists?(conn, base, :get, "github")
      assert route_exists?(conn, base, :post, "magic_link/request")
    end
  end
end
