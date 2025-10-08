# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.ControllerTest do
  @moduledoc false
  use AshAuthentication.Phoenix.Test.ConnCase

  describe "AshAuthentication Controller" do
    test "sign-in renders", %{conn: conn} do
      assert_mount_render(conn, ~p"/sign-in", "Sign in")
    end

    test "register renders", %{conn: conn} do
      assert_mount_render(conn, ~p"/register", "Register")
    end

    test "reset renders", %{conn: conn} do
      assert_mount_render(conn, ~p"/reset", "Request magic link")
    end

    test "sign-out renders", %{conn: conn} do
      conn = get(conn, ~p"/sign-out")
      assert html_response(conn, 200) =~ "Signed out"
      assert {:error, :nosession} = live(conn)
    end

    defp assert_mount_render(conn, path, response) do
      conn = get(conn, path)

      # assert unconnected mount renders
      assert html_response(conn, 200) =~ response

      # assert connected mount also renders
      assert {:ok, _view, html} = live(conn)
      assert html =~ response
      conn
    end

    test "register user with password", %{conn: conn} do
      strategy = AshAuthentication.Info.strategy!(Example.Accounts.User, :password)
      email = "register@email"
      password = "register.secret"

      {:ok, lv, _html} = live(conn, ~p"/register")

      {:ok, conn} =
        lv
        |> form(~s{[action="/auth/user/password/register"]},
          user: %{
            strategy.identity_field => email,
            strategy.password_field => password,
            strategy.password_confirmation_field => password
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html_response(conn, 200) =~ "Success"
      assert Ash.CiString.value(conn.assigns.current_user.email) == email
    end

    test "sign-in user with password", %{conn: conn} do
      strategy = AshAuthentication.Info.strategy!(Example.Accounts.User, :password)
      email = "sign.in@email"
      password = "sign.in.secret"
      create_user!(strategy, email, password)
      conn = sign_in_user(conn, strategy, email, password)

      assert html_response(conn, 200) =~ "Success"
      assert get_session(conn, :user) != nil
      assert Ash.CiString.value(conn.assigns.current_user.email) == email
    end

    test "sign-out user", %{conn: conn} do
      strategy = AshAuthentication.Info.strategy!(Example.Accounts.User, :password)
      email = "sign.out@email"
      password = "sign.out.secret"
      create_user!(strategy, email, password)

      conn =
        conn
        |> sign_in_user(strategy, email, password)
        |> get(~p"/sign-out")

      assert html_response(conn, 200) =~ "Signed out"
      assert get_session(conn, :user) == nil
    end
  end

  defp sign_in_user(conn, strategy, email, password) do
    {:ok, lv, _html} = live(conn, ~p"/sign-in")

    {:ok, conn} =
      lv
      |> form(~s{[action="/auth/user/password/sign_in"]},
        user: %{
          strategy.identity_field => email,
          strategy.password_field => password
        }
      )
      |> render_submit()
      |> follow_redirect(conn)

    conn
  end

  defp create_user!(strategy, email, password) do
    Example.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      strategy.identity_field => email,
      strategy.password_field => password,
      strategy.password_confirmation_field => password
    })
    |> Ash.create!()
  end
end
