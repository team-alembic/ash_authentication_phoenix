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
end
