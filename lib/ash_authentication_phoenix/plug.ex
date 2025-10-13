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
  @spec store_in_session(Conn.t(), Ash.Resource.record()) :: Conn.t()
  defdelegate store_in_session(conn, actor), to: AshAuthentication.Plug.Helpers
end
