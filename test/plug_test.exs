# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.PlugTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Plug.Test
  alias AshAuthentication.Phoenix.Plug

  defp skip(conn, opts \\ []),
    do: Plug.skip_csrf_for_oauth_callback(conn, opts)

  describe "skip_csrf_for_oauth_callback/2" do
    test "skips CSRF for a POST to an OAuth callback path" do
      conn = skip(conn(:post, "/auth/user/auth0/callback"))
      assert conn.private[:plug_skip_csrf_protection] == true
    end

    test "does not skip CSRF for a GET to a callback path" do
      conn = skip(conn(:get, "/auth/user/auth0/callback"))
      refute conn.private[:plug_skip_csrf_protection]
    end

    test "does not skip CSRF for other authentication POSTs (e.g. password sign-in)" do
      conn = skip(conn(:post, "/auth/user/password/sign_in"))
      refute conn.private[:plug_skip_csrf_protection]
    end

    test "does not skip CSRF for POSTs outside the auth prefix" do
      conn = skip(conn(:post, "/other/thing/callback"))
      refute conn.private[:plug_skip_csrf_protection]
    end

    test "respects a custom :auth_routes_prefix" do
      conn =
        conn(:post, "/nested/auth/user/auth0/callback")
        |> skip(auth_routes_prefix: "/nested/auth")

      assert conn.private[:plug_skip_csrf_protection] == true
    end
  end
end
