# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule DevWeb.AuthController do
  @moduledoc false

  use DevWeb, :controller
  use AshAuthentication.Phoenix.Controller

  @doc false
  @impl true
  def success(conn, _activity, user, _token) do
    conn
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: "/")
  end

  @doc false
  @impl true
  def failure(conn, _activity, reason) do
    # Surface the reason in a flash — a silent redirect back to the sign-in
    # page is indistinguishable from nothing having happened.
    message =
      if is_exception(reason), do: Exception.message(reason), else: inspect(reason)

    conn
    |> assign(:failure_reason, reason)
    |> put_flash(:error, "Authentication failed: #{message}")
    |> redirect(to: "/sign-in")
  end

  @doc false
  @impl true
  def sign_out(conn, _params) do
    conn
    |> clear_session(:ash_authentication_phoenix)
    |> redirect(to: "/")
  end
end
