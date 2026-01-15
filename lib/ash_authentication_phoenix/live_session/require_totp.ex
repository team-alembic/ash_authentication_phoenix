# SPDX-FileCopyrightText: 2024 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.LiveSession.RequireTotp do
  @moduledoc """
  A LiveView on_mount hook that enforces TOTP two-factor authentication.

  This module provides an on_mount hook that checks if the current user has
  TOTP configured and redirects to the setup page if not.

  ## Usage

  Add the hook to your live_session in the router:

      live_session :require_totp,
        on_mount: [
          {AshAuthentication.Phoenix.LiveSession, :default},
          {AshAuthentication.Phoenix.LiveSession.RequireTotp, :require_totp}
        ] do
        live "/secure", SecureLive
      end

  Or use the `require_totp/1` function in your own on_mount callback:

      defmodule MyAppWeb.RequireTotpHook do
        alias AshAuthentication.Phoenix.LiveSession.RequireTotp

        def on_mount(:default, params, session, socket) do
          RequireTotp.require_totp(socket,
            setup_path: "/settings/security/2fa",
            error_message: "Please set up two-factor authentication"
          )
        end
      end

  ## Options

    * `:current_user_assign` - The assign key for the current user. Defaults to
      `:current_user`.

    * `:setup_path` - The path to redirect to for TOTP setup. Defaults to
      `"/auth/totp/setup"`.

    * `:error_message` - The flash message to show when redirecting. Defaults to
      `"Two-factor authentication required"`.

    * `:strategy` - The name of the TOTP strategy. Defaults to the first TOTP
      strategy found on the resource.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, redirect: 2]
  alias AshAuthentication.Phoenix.TotpHelpers

  @default_setup_path "/auth/totp/setup"
  @default_error_message "Two-factor authentication required"

  @doc """
  LiveView on_mount callback that requires TOTP configuration.

  Can be configured with a tuple in the live_session:

      on_mount: [{AshAuthentication.Phoenix.LiveSession.RequireTotp, :require_totp}]

  Or with options:

      on_mount: [{AshAuthentication.Phoenix.LiveSession.RequireTotp,
                  {:require_totp, setup_path: "/custom/setup"}}]
  """
  def on_mount(:require_totp, _params, _session, socket) do
    require_totp(socket)
  end

  def on_mount({:require_totp, opts}, _params, _session, socket) when is_list(opts) do
    require_totp(socket, opts)
  end

  @doc """
  Checks if the current user has TOTP configured and redirects if not.

  Returns `{:cont, socket}` if TOTP is configured, or `{:halt, socket}` with
  a redirect if not.

  ## Options

    * `:current_user_assign` - The assign key for the current user. Defaults to
      `:current_user`.

    * `:setup_path` - The path to redirect to for TOTP setup.

    * `:error_message` - The flash message to show when redirecting.

    * `:strategy` - The name of the TOTP strategy.
  """
  @spec require_totp(Phoenix.LiveView.Socket.t(), keyword()) ::
          {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}
  def require_totp(socket, opts \\ []) do
    current_user_assign = Keyword.get(opts, :current_user_assign, :current_user)
    setup_path = Keyword.get(opts, :setup_path, @default_setup_path)
    error_message = Keyword.get(opts, :error_message, @default_error_message)
    strategy = Keyword.get(opts, :strategy)

    user = socket.assigns[current_user_assign]

    cond do
      is_nil(user) ->
        {:cont, socket}

      TotpHelpers.totp_configured?(user, strategy: strategy) ->
        {:cont, assign(socket, :totp_configured, true)}

      true ->
        socket =
          socket
          |> assign(:totp_configured, false)
          |> put_flash(:error, error_message)
          |> redirect(to: setup_path)

        {:halt, socket}
    end
  end

  @doc """
  Returns true if the current user has TOTP configured.

  This is a convenience function for use in LiveView templates:

      <%= if totp_configured?(@socket) do %>
        <span>2FA enabled</span>
      <% end %>
  """
  @spec totp_configured?(Phoenix.LiveView.Socket.t(), keyword()) :: boolean()
  def totp_configured?(socket, opts \\ []) do
    current_user_assign = Keyword.get(opts, :current_user_assign, :current_user)
    strategy = Keyword.get(opts, :strategy)

    case socket.assigns[current_user_assign] do
      nil -> false
      user -> TotpHelpers.totp_configured?(user, strategy: strategy)
    end
  end
end
