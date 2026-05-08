# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.LiveSession.RequireWebAuthn do
  @moduledoc """
  A LiveView `on_mount` hook that enforces WebAuthn second-factor verification
  for live routes.

  Mirrors `AshAuthentication.Phoenix.Plug.RequireWebAuthn` for LiveView. With
  no current user, falls through. Otherwise:

    * If the user has no registered passkeys, redirects to the setup path
      (default `"/webauthn-setup"`).
    * If the request lacks `:webauthn_verified_at` (or it's older than
      `:max_age`), redirects to the verify path (default `"/webauthn-verify"`).
    * Otherwise, continues.

  ## Usage

      live_session :secure,
        on_mount: [
          {AshAuthentication.Phoenix.LiveSession, :default},
          {AshAuthentication.Phoenix.LiveSession.RequireWebAuthn, :require_webauthn}
        ] do
        live "/admin", AdminLive
      end

  Pass options as a tuple to override defaults:

      on_mount: [
        {AshAuthentication.Phoenix.LiveSession.RequireWebAuthn,
          {:require_webauthn, max_age: 300, verify_path: "/step-up"}}
      ]

  ## Options

    * `:strategy` — WebAuthn strategy name. Defaults to the first WebAuthn
      strategy on the user's resource.
    * `:setup_path` — defaults to `"/webauthn-setup"`.
    * `:verify_path` — defaults to `"/webauthn-verify"`.
    * `:max_age` — maximum age (seconds) of `:webauthn_verified_at`.
    * `:current_user_assign` — defaults to `:current_user`.
    * `:setup_error_message` / `:verify_error_message` — flash text.
  """

  import Phoenix.LiveView, only: [put_flash: 3, redirect: 2]
  alias AshAuthentication.Phoenix.WebAuthnHelpers

  @default_setup_path "/webauthn-setup"
  @default_verify_path "/webauthn-verify"
  @default_setup_error "Please register a passkey to continue."
  @default_verify_error "Please verify your identity with your passkey to continue."

  @doc """
  LiveView `on_mount/4` callback that requires WebAuthn verification.

  Use as `{AshAuthentication.Phoenix.LiveSession.RequireWebAuthn, :require_webauthn}`
  or `{module, {:require_webauthn, opts}}`.
  """
  def on_mount(:require_webauthn, _params, _session, socket),
    do: require_webauthn(socket)

  def on_mount({:require_webauthn, opts}, _params, _session, socket) when is_list(opts),
    do: require_webauthn(socket, opts)

  @doc """
  Checks the socket against the WebAuthn requirements and either continues
  or redirects.
  """
  @spec require_webauthn(Phoenix.LiveView.Socket.t(), keyword()) ::
          {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}
  def require_webauthn(socket, opts \\ []) do
    current_user_assign = Keyword.get(opts, :current_user_assign, :current_user)
    setup_path = Keyword.get(opts, :setup_path, @default_setup_path)
    verify_path = Keyword.get(opts, :verify_path, @default_verify_path)
    setup_error = Keyword.get(opts, :setup_error_message, @default_setup_error)
    verify_error = Keyword.get(opts, :verify_error_message, @default_verify_error)
    max_age = Keyword.get(opts, :max_age)
    strategy = Keyword.get(opts, :strategy)

    user = socket.assigns[current_user_assign]

    cond do
      is_nil(user) ->
        {:cont, socket}

      not WebAuthnHelpers.webauthn_configured?(user, strategy: strategy) ->
        {:halt,
         socket
         |> put_flash(:error, setup_error)
         |> redirect(to: setup_path)}

      WebAuthnHelpers.webauthn_verified?(socket,
        max_age: max_age,
        current_user_assign: current_user_assign
      ) ->
        {:cont, socket}

      true ->
        {:halt,
         socket
         |> put_flash(:error, verify_error)
         |> redirect(to: verify_path)}
    end
  end
end
