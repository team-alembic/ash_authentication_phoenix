defmodule DevWeb.Router do
  @moduledoc false

  use DevWeb, :router
  # use AshPhoenix.Authentication.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {DevWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DevWeb do
    pipe_through(:browser)

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", DevWeb do
  #   pipe_through :api
  # end

  # scope "/" do
  #   pipe_through :browser
  #   auth_routes DevWeb.AuthController, "/auth"
  #   sign_in_route "/sign-in"
  #   sign_out_route DevWeb.AuthController, "/sign-out"
  # end
end
