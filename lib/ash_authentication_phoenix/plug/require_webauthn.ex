# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Plug.RequireWebAuthn do
  @moduledoc """
  A plug that enforces WebAuthn second-factor verification for routes.

  ## Behaviour

  When called against a request that has a `current_user`:

    * If the user has no registered passkeys, fires the `on_unconfigured`
      action (default `:redirect_to_setup`).
    * If the user has passkeys but the current request lacks
      `:webauthn_verified_at` metadata (or it's older than `:max_age`),
      fires the `on_unverified` action (default `:redirect_to_verify`).
    * Otherwise, passes through.

  When the request has no current user, the plug passes through — pair it
  with your auth pipeline so a user is loaded first.

  ## Usage

      pipeline :require_webauthn do
        plug AshAuthentication.Phoenix.Plug.RequireWebAuthn,
          resource: MyApp.Accounts.User
      end

      scope "/secure", MyAppWeb do
        pipe_through [:browser, :require_authenticated, :require_webauthn]
        # ...
      end

  ## Options

    * `:resource` — required. The user resource module.

    * `:strategy` — the WebAuthn strategy name. Defaults to the first
      WebAuthn strategy on the resource.

    * `:on_unconfigured` — what to do when the user has no passkeys:
      * `:halt` — return a 403.
      * `:redirect_to_setup` (default) — redirect to `:setup_path`.
      * `{:redirect, path}` — redirect to `path`.

    * `:on_unverified` — what to do when the user has passkeys but the
      request isn't verified:
      * `:halt` — return a 403.
      * `:redirect_to_verify` (default) — redirect to `:verify_path`.
      * `{:redirect, path}` — redirect to `path`.

    * `:setup_path` — defaults to `"/webauthn-setup"`.
    * `:verify_path` — defaults to `"/webauthn-verify"`.
    * `:max_age` — maximum age (seconds) of `:webauthn_verified_at` before
      re-verification is required. `nil` (default) means no expiry.
    * `:current_user_assign` — defaults to `:current_user`.
    * `:setup_error_message` — flash text when redirecting to setup.
    * `:verify_error_message` — flash text when redirecting to verify.
  """

  @behaviour Plug

  import Plug.Conn
  alias AshAuthentication.Phoenix.WebAuthnHelpers

  @default_setup_path "/webauthn-setup"
  @default_verify_path "/webauthn-verify"
  @default_setup_error "Please register a passkey to continue."
  @default_verify_error "Please verify your identity with your passkey to continue."

  @impl Plug
  def init(opts) do
    %{
      resource: Keyword.fetch!(opts, :resource),
      strategy: Keyword.get(opts, :strategy),
      on_unconfigured: Keyword.get(opts, :on_unconfigured, :redirect_to_setup),
      on_unverified: Keyword.get(opts, :on_unverified, :redirect_to_verify),
      setup_path: Keyword.get(opts, :setup_path, @default_setup_path),
      verify_path: Keyword.get(opts, :verify_path, @default_verify_path),
      max_age: Keyword.get(opts, :max_age),
      current_user_assign: Keyword.get(opts, :current_user_assign, :current_user),
      setup_error_message: Keyword.get(opts, :setup_error_message, @default_setup_error),
      verify_error_message: Keyword.get(opts, :verify_error_message, @default_verify_error)
    }
  end

  @impl Plug
  def call(conn, opts) do
    user = conn.assigns[opts.current_user_assign]

    cond do
      is_nil(user) ->
        conn

      not WebAuthnHelpers.webauthn_configured?(user, strategy: opts.strategy) ->
        handle_unconfigured(conn, opts)

      WebAuthnHelpers.webauthn_verified?(conn,
        max_age: opts.max_age,
        current_user_assign: opts.current_user_assign
      ) ->
        conn

      true ->
        handle_unverified(conn, opts)
    end
  end

  defp handle_unconfigured(conn, %{on_unconfigured: :halt} = opts),
    do: halt_403(conn, opts.setup_error_message)

  defp handle_unconfigured(conn, %{on_unconfigured: :redirect_to_setup} = opts),
    do: redirect_with_flash(conn, opts.setup_path, opts.setup_error_message)

  defp handle_unconfigured(conn, %{on_unconfigured: {:redirect, path}} = opts),
    do: redirect_with_flash(conn, path, opts.setup_error_message)

  defp handle_unverified(conn, %{on_unverified: :halt} = opts),
    do: halt_403(conn, opts.verify_error_message)

  defp handle_unverified(conn, %{on_unverified: :redirect_to_verify} = opts),
    do: redirect_with_flash(conn, opts.verify_path, opts.verify_error_message)

  defp handle_unverified(conn, %{on_unverified: {:redirect, path}} = opts),
    do: redirect_with_flash(conn, path, opts.verify_error_message)

  defp halt_403(conn, message) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(403, message)
    |> halt()
  end

  defp redirect_with_flash(conn, path, message) do
    conn
    |> Phoenix.Controller.put_flash(:error, message)
    |> Phoenix.Controller.redirect(to: path)
    |> halt()
  end
end
