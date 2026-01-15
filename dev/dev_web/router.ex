# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

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
    plug :set_actor, :user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DevWeb do
    pipe_through(:browser)

    ash_authentication_live_session do
      live "/", HomePageLive
      live "/custom-sign-in", CustomSignInLive
    end
  end

  scope "/", DevWeb do
    pipe_through :browser

    sign_out_route(AuthController, "/sign-out")
    reset_route(auth_routes_prefix: "/auth")

    magic_sign_in_route(Example.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [DevWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.DaisyUI]
    )

    sign_in_route(
      path: "/sign-in",
      overrides: [DevWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.DaisyUI],
      auth_routes_prefix: "/auth"
    )

    totp_2fa_route(Example.Accounts.User, :totp,
      auth_routes_prefix: "/auth",
      overrides: [DevWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.DaisyUI]
    )

    totp_setup_route(Example.Accounts.User, :totp,
      auth_routes_prefix: "/auth",
      overrides: [DevWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.DaisyUI]
    )

    auth_routes(AuthController, Example.Accounts.User)
  end
end
