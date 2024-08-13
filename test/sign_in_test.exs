defmodule AshAuthentication.Phoenix.SignInTest do
  @moduledoc false

  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  require Ash.Query

  @endpoint AshAuthentication.Phoenix.Test.Endpoint

  setup do
    # foo
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  test "sign_in routes liveview renders the sign in page", %{conn: conn} do
    conn = get(conn, "/sign-in")
    assert {:ok, _view, html} = live(conn)
    assert html =~ "Sign in"
  end

  test "sign_in routes allow a user to sign in", %{conn: conn} do
    Example.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: "zach@example.com",
      password: "so-secure!",
      password_confirmation: "so-secure!"
    })
    |> Ash.create!()

    conn = get(conn, "/sign-in")
    assert {:ok, lv, _html} = live(conn)

    lv
    |> form("#user-password-sign-in-with-password", %{
      "user" => %{
        "email" => "zach@example.com",
        "password" => "so-secure!"
      }
    })
    |> render_submit()

    assert_received {_ref, {:redirect, _topic, %{to: new_to}}}
    assert %{path: "/auth/user/password/sign_in_with_token"} = URI.parse(new_to)
  end

  describe "context" do
    setup do
      Application.put_env(:ash_authentication_phoenix, :test_context, %{should_fail: true})

      on_exit(fn ->
        Application.put_env(:ash_authentication_phoenix, :test_context, nil)
      end)
    end

    test "context is preserved across requests", %{conn: conn} do
      Process.put(:test_context, %{should_fail: true})
      conn = get(conn, "/sign-in")
      assert {:ok, lv, _html} = live(conn)

      result =
        lv
        |> form("#user-password-sign-in-with-password", %{
          "user" => %{
            "email" => "zach@example.com",
            "password" => "so-secure!"
          }
        })
        |> render_submit()

      assert result =~ "I cant let you do that dave"
    end
  end
end
