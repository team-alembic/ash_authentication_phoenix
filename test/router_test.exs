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
    test "only option includes only specified strategies and add-ons" do
      only_routes =
        AshAuthentication.Phoenix.Test.Router
        |> Phoenix.Router.routes()
        |> Enum.filter(&String.starts_with?(&1.path, "/auth-only"))

      strategy_names =
        only_routes
        |> Enum.map(fn route ->
          route.path
          |> String.split("/")
          |> Enum.at(2)
        end)
        |> Enum.uniq()
        |> Enum.reject(&is_nil/1)

      assert "password" in strategy_names
      assert "github" in strategy_names

      refute "auth0" in strategy_names
      refute "slack" in strategy_names
      refute "twitch" in strategy_names
      refute "magic_link" in strategy_names
    end

    test "except option excludes specified strategies and add-ons" do
      except_routes =
        AshAuthentication.Phoenix.Test.Router
        |> Phoenix.Router.routes()
        |> Enum.filter(&String.starts_with?(&1.path, "/auth-except"))

      strategy_names =
        except_routes
        |> Enum.map(fn route ->
          route.path
          |> String.split("/")
          |> Enum.at(2)
        end)
        |> Enum.uniq()
        |> Enum.reject(&is_nil/1)

      assert "password" in strategy_names
      assert "github" in strategy_names
      assert "magic_link" in strategy_names

      refute "auth0" in strategy_names
      refute "slack" in strategy_names
      refute "twitch" in strategy_names
    end

    test "unfiltered auth_routes includes all strategies and add-ons" do
      all_routes =
        AshAuthentication.Phoenix.Test.Router
        |> Phoenix.Router.routes()
        |> Enum.filter(fn route ->
          String.starts_with?(route.path, "/auth/")
        end)

      strategy_names =
        all_routes
        |> Enum.map(fn route ->
          route.path
          |> String.split("/")
          |> Enum.at(2)
        end)
        |> Enum.uniq()
        |> Enum.reject(&is_nil/1)

      assert "password" in strategy_names
      assert "auth0" in strategy_names
      assert "github" in strategy_names
      assert "slack" in strategy_names
      assert "twitch" in strategy_names
      assert "magic_link" in strategy_names
    end
  end
end
