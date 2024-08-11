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

    @tag failing: "yes"
    test "register user", %{conn: conn} do
      strategy = AshAuthentication.Info.strategy!(Example.Accounts.User, :password)

      {:ok, lv, _html} = live(conn, ~p"/register")

      {:ok, conn} =
        lv
        |> form(~s{[action="/auth/user/password/register?"]},
          user: %{
            strategy.identity_field => "some@email",
            strategy.password_field => "some password",
            strategy.password_confirmation_field => "some password"
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert get_session(conn, :user_token)
      assert conn.assigns.current_user
    end

    @tag failing: "yes"
    test "sign-in user", %{conn: conn} do
      strategy = AshAuthentication.Info.strategy!(Example.Accounts.User, :password)

      {:ok, lv, _html} = live(conn, ~p"/sign-in")

      {:ok, conn} =
        lv
        |> form(~s{[action="/auth/user/password/sign_in?"]},
          user: %{
            strategy.identity_field => "some@email",
            strategy.password_field => "some password"
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html_response(conn, 200) =~ "Success"
      assert get_session(conn, :user_token)
      assert conn.assigns.current_user
    end
  end
end
