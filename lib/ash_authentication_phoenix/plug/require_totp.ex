# SPDX-FileCopyrightText: 2024 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Plug.RequireTotp do
  @moduledoc """
  A plug that enforces TOTP two-factor authentication for routes.

  This plug checks if the current user has TOTP configured and can optionally
  redirect users who haven't set up TOTP to the setup page.

  ## Usage

  In your router, add the plug to a pipeline:

      pipeline :require_totp do
        plug AshAuthentication.Phoenix.Plug.RequireTotp,
          resource: MyApp.Accounts.User,
          on_missing: :redirect_to_setup,
          setup_path: "/auth/totp/setup"
      end

      scope "/secure", MyAppWeb do
        pipe_through [:browser, :require_auth, :require_totp]
        # Protected routes that require 2FA
      end

  ## Options

    * `:resource` - Required. The user resource module that has the TOTP strategy.

    * `:strategy` - Optional. The name of the TOTP strategy. Defaults to the
      first TOTP strategy found on the resource.

    * `:on_missing` - What to do when TOTP is not configured. Options:
      * `:halt` - Return a 403 forbidden response (default)
      * `:redirect_to_setup` - Redirect to the TOTP setup page
      * `{:redirect, path}` - Redirect to a custom path

    * `:setup_path` - The path to redirect to for TOTP setup. Defaults to
      `"/auth/totp/setup"`. Only used when `:on_missing` is `:redirect_to_setup`.

    * `:current_user_assign` - The assign key for the current user. Defaults to
      `:current_user`.

    * `:error_message` - The flash message to show when redirecting. Defaults to
      `"Two-factor authentication required"`.

  ## Examples

  ### Require TOTP, redirect to setup if not configured

      plug AshAuthentication.Phoenix.Plug.RequireTotp,
        resource: MyApp.Accounts.User,
        on_missing: :redirect_to_setup

  ### Require TOTP, return 403 if not configured

      plug AshAuthentication.Phoenix.Plug.RequireTotp,
        resource: MyApp.Accounts.User,
        on_missing: :halt

  ### Custom redirect path

      plug AshAuthentication.Phoenix.Plug.RequireTotp,
        resource: MyApp.Accounts.User,
        on_missing: {:redirect, "/settings/security"}
  """

  @behaviour Plug

  import Plug.Conn
  alias AshAuthentication.Phoenix.TotpHelpers

  @default_setup_path "/auth/totp/setup"
  @default_error_message "Two-factor authentication required"

  @impl Plug
  def init(opts) do
    resource = Keyword.fetch!(opts, :resource)

    %{
      resource: resource,
      strategy: Keyword.get(opts, :strategy),
      on_missing: Keyword.get(opts, :on_missing, :halt),
      setup_path: Keyword.get(opts, :setup_path, @default_setup_path),
      current_user_assign: Keyword.get(opts, :current_user_assign, :current_user),
      error_message: Keyword.get(opts, :error_message, @default_error_message)
    }
  end

  @impl Plug
  def call(conn, opts) do
    user = conn.assigns[opts.current_user_assign]

    cond do
      is_nil(user) ->
        conn

      TotpHelpers.totp_configured?(user, strategy: opts.strategy) ->
        conn

      true ->
        handle_missing_totp(conn, opts)
    end
  end

  defp handle_missing_totp(conn, %{on_missing: :halt} = opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(403, opts.error_message)
    |> halt()
  end

  defp handle_missing_totp(conn, %{on_missing: :redirect_to_setup} = opts) do
    redirect_with_flash(conn, opts.setup_path, opts.error_message)
  end

  defp handle_missing_totp(conn, %{on_missing: {:redirect, path}} = opts) do
    redirect_with_flash(conn, path, opts.error_message)
  end

  defp redirect_with_flash(conn, path, message) do
    conn
    |> Phoenix.Controller.put_flash(:error, message)
    |> Phoenix.Controller.redirect(to: path)
    |> halt()
  end
end
