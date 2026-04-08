defmodule AshAuthentication.Phoenix.Plug.RequireRecoveryCodes do
  @moduledoc """
  A plug that enforces recovery code configuration for routes.

  This plug checks if the current user has recovery codes configured and can
  optionally redirect users who haven't set up recovery codes to the setup page.

  ## Behaviour When No User Is Present

  When there is no authenticated user, this plug passes through without
  modification. Use this plug **after** your authentication plug.

  ## Usage

      pipeline :require_recovery_codes do
        plug AshAuthentication.Phoenix.Plug.RequireRecoveryCodes,
          resource: MyApp.Accounts.User,
          on_missing: :redirect_to_setup,
          setup_path: "/recovery-codes"
      end

  ## Options

    * `:resource` - Required. The user resource module.
    * `:strategy` - Optional. The name of the recovery code strategy.
    * `:on_missing` - What to do when recovery codes are not configured:
      * `:halt` - Return a 403 response (default)
      * `:redirect_to_setup` - Redirect to the setup page
      * `{:redirect, path}` - Redirect to a custom path
    * `:setup_path` - Path to redirect to. Defaults to `"/recovery-codes"`.
    * `:current_user_assign` - The assign key for the current user. Defaults to `:current_user`.
    * `:error_message` - Flash message when redirecting. Defaults to `"Recovery codes required"`.
  """

  @behaviour Plug

  import Plug.Conn
  alias AshAuthentication.Phoenix.RecoveryCodeHelpers

  @default_setup_path "/recovery-codes"
  @default_error_message "Recovery codes required"

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

      RecoveryCodeHelpers.recovery_codes_configured?(user, strategy: opts.strategy) ->
        conn

      true ->
        handle_missing(conn, opts)
    end
  end

  defp handle_missing(conn, %{on_missing: :halt} = opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(403, opts.error_message)
    |> halt()
  end

  defp handle_missing(conn, %{on_missing: :redirect_to_setup} = opts) do
    redirect_with_flash(conn, opts.setup_path, opts.error_message)
  end

  defp handle_missing(conn, %{on_missing: {:redirect, path}} = opts) do
    redirect_with_flash(conn, path, opts.error_message)
  end

  defp redirect_with_flash(conn, path, message) do
    conn
    |> Phoenix.Controller.put_flash(:error, message)
    |> Phoenix.Controller.redirect(to: path)
    |> halt()
  end
end
