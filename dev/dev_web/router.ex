defmodule DevWeb.Router do
  @moduledoc false

  use DevWeb, :router
  use AshAuthentication.Phoenix.Router, otp_app: :ash_authentication_phoenix

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {DevWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DevWeb do
    pipe_through(:browser)

    ash_authentication_live_session do
      live "/", HomePageLive
    end
  end

  scope "/", DevWeb do
    pipe_through :browser
    auth_routes_for(Example.Accounts.User, to: AuthController, path: "/auth")
    sign_in_route(overrides: [DevWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default])
    sign_out_route(AuthController, "/sign-out")
    reset_route()
  end
end
