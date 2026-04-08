defmodule AshAuthentication.Phoenix.LiveSession.RequireRecoveryCodes do
  @moduledoc """
  A LiveView on_mount hook that enforces recovery code configuration.

  This module provides an on_mount hook that checks if the current user has
  recovery codes configured and redirects to the setup page if not.

  ## Behaviour When No User Is Present

  When there is no authenticated user, this hook returns `{:cont, socket}`
  without modification. Use this hook **after** your authentication hook.

  ## Usage

      live_session :require_recovery_codes,
        on_mount: [
          {AshAuthentication.Phoenix.LiveSession, :default},
          {AshAuthentication.Phoenix.LiveSession.RequireRecoveryCodes, :require_recovery_codes}
        ] do
        live "/secure", SecureLive
      end

  ## Options

    * `:current_user_assign` - The assign key for the current user. Defaults to `:current_user`.
    * `:setup_path` - Path to redirect to. Defaults to `"/recovery-codes"`.
    * `:error_message` - Flash message when redirecting. Defaults to `"Recovery codes required"`.
    * `:strategy` - The name of the recovery code strategy.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, redirect: 2]
  alias AshAuthentication.Phoenix.RecoveryCodeHelpers

  @default_setup_path "/recovery-codes"
  @default_error_message "Recovery codes required"

  @doc """
  LiveView on_mount callback that requires recovery code configuration.
  """
  def on_mount(:require_recovery_codes, _params, _session, socket) do
    require_recovery_codes(socket)
  end

  def on_mount({:require_recovery_codes, opts}, _params, _session, socket)
      when is_list(opts) do
    require_recovery_codes(socket, opts)
  end

  @doc """
  Checks if the current user has recovery codes configured and redirects if not.

  Returns `{:cont, socket}` if configured, or `{:halt, socket}` with a redirect if not.
  """
  @spec require_recovery_codes(Phoenix.LiveView.Socket.t(), keyword()) ::
          {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}
  def require_recovery_codes(socket, opts \\ []) do
    current_user_assign = Keyword.get(opts, :current_user_assign, :current_user)
    setup_path = Keyword.get(opts, :setup_path, @default_setup_path)
    error_message = Keyword.get(opts, :error_message, @default_error_message)
    strategy = Keyword.get(opts, :strategy)

    user = socket.assigns[current_user_assign]

    cond do
      is_nil(user) ->
        {:cont, socket}

      RecoveryCodeHelpers.recovery_codes_configured?(user, strategy: strategy) ->
        {:cont, assign(socket, :recovery_codes_configured, true)}

      true ->
        socket =
          socket
          |> assign(:recovery_codes_configured, false)
          |> put_flash(:error, error_message)
          |> redirect(to: setup_path)

        {:halt, socket}
    end
  end

  @doc """
  Returns true if the current user has recovery codes configured.
  """
  @spec recovery_codes_configured?(Phoenix.LiveView.Socket.t(), keyword()) :: boolean()
  def recovery_codes_configured?(socket, opts \\ []) do
    current_user_assign = Keyword.get(opts, :current_user_assign, :current_user)
    strategy = Keyword.get(opts, :strategy)

    case socket.assigns[current_user_assign] do
      nil -> false
      user -> RecoveryCodeHelpers.recovery_codes_configured?(user, strategy: strategy)
    end
  end
end
