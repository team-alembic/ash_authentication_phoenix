# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Plug do
  @moduledoc """
  Helper plugs mixed in to your router.

  When you `use AshAuthentication.Phoenix.Router` this module is included, so
  that you can use these plugs in your pipelines.
  """

  alias AshAuthentication.Plug.Helpers
  alias Plug.Conn

  @doc """
  Attempts to sign in the user with the remember me token if the user is not already signed in.

  A wrapper around `AshAuthentication.Plug.Helpers.sign_in_with_remember_me/2`
  with the `otp_app` as extracted from the endpoint.
  """
  @spec sign_in_with_remember_me(Conn.t(), keyword) :: Conn.t()
  def sign_in_with_remember_me(conn, opts) do
    {maybe_otp_app, opts} = Keyword.pop(opts, :otp_app)
    otp_app = maybe_otp_app || conn.private.phoenix_endpoint.config(:otp_app)

    Helpers.sign_in_using_remember_me(conn, otp_app, opts)
  end

  @doc """
  Attempt to retrieve all actors from the connections' session.

  A wrapper around `AshAuthentication.Plug.Helpers.retrieve_from_session/2`
  with the `otp_app` as extracted from the endpoint.
  """
  @spec load_from_session(Conn.t(), keyword) :: Conn.t()
  def load_from_session(conn, opts) do
    {maybe_otp_app, opts} = Keyword.pop(opts, :otp_app)
    otp_app = maybe_otp_app || conn.private.phoenix_endpoint.config(:otp_app)

    Helpers.retrieve_from_session(conn, otp_app, opts)
  end

  @doc """
  Attempt to retrieve actors from the `Authorization` header(s).

  A wrapper around `AshAuthentication.Plug.Helpers.retrieve_from_bearer/2` with
  the `otp_app` as extracted from the endpoint.
  """
  @spec load_from_bearer(Conn.t(), keyword) :: Conn.t()
  def load_from_bearer(conn, opts) do
    {maybe_otp_app, opts} = Keyword.pop(opts, :otp_app)
    otp_app = maybe_otp_app || conn.private.phoenix_endpoint.config(:otp_app)

    Helpers.retrieve_from_bearer(conn, otp_app, opts)
  end

  @doc """
  Revoke all token(s) in the `Authorization` header(s).

  A wrapper around `AshAuthentication.Plug.Helpers.revoke_bearer_tokens/2` with
  the `otp_app` as extracted from the endpoint.
  """
  @spec revoke_bearer_tokens(Conn.t(), any) :: Conn.t()
  def revoke_bearer_tokens(conn, _opts) do
    otp_app = conn.private.phoenix_endpoint.config(:otp_app)
    Helpers.revoke_bearer_tokens(conn, otp_app)
  end

  @doc """
  Revoke all token(s) in the session.

  A wrapper around `AshAuthentication.Plug.Helpers.revoke_session_tokens/2` with
  the `otp_app` as extracted from the endpoint.
  """
  @spec revoke_session_tokens(Conn.t(), any) :: Conn.t()
  def revoke_session_tokens(conn, _opts) do
    otp_app = conn.private.phoenix_endpoint.config(:otp_app)
    Helpers.revoke_session_tokens(conn, otp_app)
  end

  @doc """
  Store the actor in the connections' session.
  """
  @spec store_in_session(Conn.t(), Ash.Resource.Record.t()) :: Conn.t()
  defdelegate store_in_session(conn, actor), to: AshAuthentication.Plug.Helpers

  @doc """
  Set the actor from the connection's assigns.

  This plug takes the user from `conn.assigns.current_<subject_name>` (set by
  `load_from_session/2`) and sets it as the Ash actor via `Ash.PlugHelpers.set_actor/2`.

  This is required for authentication strategies that need to access the current
  user via `Ash.PlugHelpers.get_actor/1`.

  ## Example

      pipeline :browser do
        plug :load_from_session
        plug :set_actor, :user
      end
  """
  @spec set_actor(Conn.t(), atom) :: Conn.t()
  defdelegate set_actor(conn, subject_name), to: AshAuthentication.Plug.Helpers

  @doc """
  Skip Phoenix CSRF protection for OAuth2/OIDC callback POSTs.

  Providers that use `response_mode=form_post` (e.g. Sign in with Apple) return
  the callback as a *cross-site* POST that carries no CSRF token — the OAuth
  `state` parameter is the CSRF defence there. Phoenix's `:protect_from_forgery`
  would otherwise reject it before it reaches the callback. This plug marks such
  requests to skip CSRF, and must therefore run **before** `:protect_from_forgery`.

  Only `POST` requests to a callback path (`<auth_routes_prefix>/…/callback`) are
  affected. Every other request — including all other authentication POSTs
  (password, magic link, TOTP, WebAuthn, …) — remains fully CSRF-protected.

  ## Options

    * `:auth_routes_prefix` - the prefix your auth routes are mounted under.
      Defaults to `"/auth"`.

  ## Example

      pipeline :browser do
        # ...
        plug :skip_csrf_for_oauth_callback
        plug :protect_from_forgery
      end
  """
  @spec skip_csrf_for_oauth_callback(Conn.t(), keyword) :: Conn.t()
  def skip_csrf_for_oauth_callback(conn, opts) do
    prefix =
      opts
      |> Keyword.get(:auth_routes_prefix, "/auth")
      |> String.split("/", trim: true)

    if conn.method == "POST" and List.starts_with?(conn.path_info, prefix) and
         List.last(conn.path_info) == "callback" do
      Conn.put_private(conn, :plug_skip_csrf_protection, true)
    else
      conn
    end
  end

  @doc """
  Build a scope from the connection's assigns and store it, along with the actor.

  This plug takes the user from `conn.assigns.current_<subject_name>` (set by
  `load_from_session/2` or `load_from_bearer/2`) and the tenant from
  `Ash.PlugHelpers.get_tenant/1`, wraps them in your scope struct, and assigns it
  to `conn.assigns.current_<subject_name>_scope`. The scope struct is expected to
  implement `Ash.Scope.ToOpts`, so it can be passed straight into Ash actions:

      Ash.read!(query, scope: conn.assigns.current_user_scope)

  It is a superset of `set_actor/2` — it also sets the Ash actor via
  `Ash.PlugHelpers.set_actor/2`, so use `set_scope` *instead of* `set_actor`, not
  alongside it.

  The scope module is referenced only as data and instantiated at runtime with
  `Kernel.struct/2`, so this plug introduces no compile-time dependency on your
  scope module (and therefore no router recompilation cycle). Keys absent from the
  struct are ignored rather than raising.

  ## Options

  Pass the scope module directly for the common single-subject case, or a keyword
  list to override the subject:

    * `:scope` - the scope module to instantiate. Required.
    * `:subject` - the subject name to build the scope for. Defaults to `:user`.

  ## Example

      pipeline :browser do
        plug :load_from_session
        plug :set_scope, MyApp.Accounts.Scope
      end

      pipeline :admin do
        plug :load_from_session
        plug :set_scope, scope: MyApp.Accounts.Scope, subject: :admin
      end
  """
  @spec set_scope(Conn.t(), module | keyword) :: Conn.t()
  def set_scope(conn, scope_module) when is_atom(scope_module) and not is_nil(scope_module),
    do: set_scope(conn, scope: scope_module)

  # sobelow_skip ["DOS.StringToAtom"]
  def set_scope(conn, opts) when is_list(opts) do
    scope_module = Keyword.fetch!(opts, :scope)
    subject_name = Keyword.get(opts, :subject, :user)

    actor = conn.assigns[String.to_existing_atom("current_#{subject_name}")]
    tenant = Ash.PlugHelpers.get_tenant(conn)
    scope = struct(scope_module, %{actor: actor, tenant: tenant})

    conn
    |> Conn.assign(String.to_atom("current_#{subject_name}_scope"), scope)
    |> Ash.PlugHelpers.set_actor(actor)
  end
end
