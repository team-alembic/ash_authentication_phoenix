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
                  "reset_path" => "/reset"
                }
              ]}
  end
end
