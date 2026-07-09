# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.PlugTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import Plug.Test
  alias AshAuthentication.Phoenix.Plug, as: AuthPlug

  defp skip(conn, opts \\ []),
    do: AuthPlug.skip_csrf_for_oauth_callback(conn, opts)

  defp register_user(email) do
    Example.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: "secure-password",
      password_confirmation: "secure-password"
    })
    |> Ash.create!()
  end

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

  describe "set_scope/2" do
    test "wraps the current subject and tenant in the scope struct" do
      user = register_user("set-scope-user@example.com")

      conn =
        conn(:get, "/")
        |> Plug.Conn.assign(:current_user, user)
        |> Ash.PlugHelpers.set_tenant("tenant-1")
        |> AuthPlug.set_scope(Example.Accounts.Scope)

      scope = conn.assigns.current_user_scope
      assert %Example.Accounts.Scope{} = scope
      assert scope.actor.id == user.id
      assert scope.tenant == "tenant-1"
    end

    test "also sets the Ash actor, superseding set_actor" do
      user = register_user("set-scope-actor@example.com")

      conn =
        conn(:get, "/")
        |> Plug.Conn.assign(:current_user, user)
        |> AuthPlug.set_scope(Example.Accounts.Scope)

      assert Ash.PlugHelpers.get_actor(conn).id == user.id
    end

    test "builds an anonymous scope when no subject is present" do
      conn =
        conn(:get, "/")
        |> Plug.Conn.assign(:current_user, nil)
        |> AuthPlug.set_scope(Example.Accounts.Scope)

      assert %Example.Accounts.Scope{actor: nil} = conn.assigns.current_user_scope
      assert Ash.PlugHelpers.get_actor(conn) == nil
    end

    test "honours the :subject option for non-default subjects" do
      admin =
        Example.Accounts.Admin
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "set-scope-admin@example.com",
          password: "secure-password",
          password_confirmation: "secure-password"
        })
        |> Ash.create!()

      conn =
        conn(:get, "/")
        |> Plug.Conn.assign(:current_admin, admin)
        |> AuthPlug.set_scope(scope: Example.Accounts.Scope, subject: :admin)

      assert conn.assigns.current_admin_scope.actor.id == admin.id
    end
  end
end
