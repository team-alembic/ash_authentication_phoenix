# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.SignInTest do
  @moduledoc false

  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  require Ash.Query

  @endpoint AshAuthentication.Phoenix.Test.Endpoint

  @jwt ~r/[\w-]{16,}\.[\w-]{16,}\.[\w-]{16,}/

  setup do
    # foo
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  test "sign_in routes liveview renders the sign in page", %{conn: conn} do
    conn = get(conn, "/sign-in")
    assert {:ok, view, _html} = live(conn)

    assert element(
             view,
             "div#user-password-sign-in-with-password-wrapper:not(.hidden)",
             "Sign in"
           )
           |> render()
  end

  describe "when sign_in_token_via_post? is not set" do
    test "sign_in routes allow a user to sign in", %{conn: conn} do
      register_user("zach@example.com")

      conn = get(conn, "/sign-in")
      assert {:ok, lv, _html} = live(conn)

      result = submit_sign_in(lv, "#user-password-sign-in-with-password", "zach@example.com")

      assert [url] = hand_off_urls(lv, result)
      assert %{path: "/auth/user/password/sign_in_with_token"} = URI.parse(url)
    end

    test "the token still travels in the query string", %{conn: conn} do
      register_user("query@example.com")

      conn = get(conn, "/sign-in")
      assert {:ok, lv, _html} = live(conn)

      result = submit_sign_in(lv, "#user-password-sign-in-with-password", "query@example.com")

      assert [url] = hand_off_urls(lv, result)
      assert URI.parse(url).query =~ @jwt
    end

    test "no hand-off form is rendered", %{conn: conn} do
      conn = get(conn, "/sign-in")
      assert {:ok, _lv, html} = live(conn)

      refute html =~ "user-password-sign-in-with-password-sign-in-with-token"
    end
  end

  describe "when sign_in_token_via_post? is set" do
    test "sign_in hands the token over without placing it in a URL", %{conn: conn} do
      register_user("post@example.com")

      conn = get(conn, "/sign-in")
      assert {:ok, lv, _html} = live(conn)

      result =
        submit_sign_in(
          lv,
          "#user-password-via-post-sign-in-with-password-via-post",
          "post@example.com"
        )

      for url <- hand_off_urls(lv, result) do
        refute url =~ @jwt, "the sign in token was placed in a URL: #{url}"
      end

      assert ["/auth/user/password_via_post/sign_in_with_token"] = hand_off_urls(lv, result)
      assert [token] = hand_off_tokens(lv, result)
      assert token =~ @jwt
    end
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

  test "sign_in routes liveview honours external gettext_fn", %{conn: conn} do
    # Translator stub at AshAuthentication.Phoenix.Test.Gettext.translate_auth
    conn = get(conn, "/anmeldung")
    assert {:ok, _view, html} = live(conn)
    refute html =~ "Sign in"
    assert html =~ "ever gonna"
  end

  test "sign_in routes liveview honours external gettext_backend", %{conn: conn} do
    # Translator stub at AshAuthentication.Phoenix.Test.Gettext
    conn = get(conn, "/anmeldung_backend")
    assert {:ok, _view, html} = live(conn)
    refute html =~ "Sign in"
    assert html =~ "ever gonna"
  end

  defp register_user(email) do
    Example.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: "so-secure!",
      password_confirmation: "so-secure!"
    })
    |> Ash.create!()
  end

  defp submit_sign_in(lv, selector, email) do
    lv
    |> form(selector, %{"user" => %{"email" => email, "password" => "so-secure!"}})
    |> render_submit()
  end

  # Every URL the browser is directed to by the submit: a redirect the LiveView
  # issued, plus the action of any form LiveView auto-submits for us.
  defp hand_off_urls(lv, result) do
    (redirect_urls(result) ++ Floki.attribute(hand_off_forms(lv, result), "action"))
    |> Enum.uniq()
  end

  defp hand_off_tokens(lv, result) do
    lv
    |> hand_off_forms(result)
    |> Floki.find(~s{input[type="hidden"][name="token"]})
    |> Floki.attribute("value")
  end

  defp hand_off_forms(lv, result) when is_binary(result) do
    lv
    |> render()
    |> Floki.parse_fragment!()
    |> Floki.find("form[phx-trigger-action]")
  end

  defp hand_off_forms(_lv, _result), do: []

  defp redirect_urls(result) do
    from_result =
      case result do
        {:error, {kind, %{to: to}}} when kind in [:redirect, :live_redirect] -> [to]
        _ -> []
      end

    from_result ++ for({_ref, {:redirect, _topic, %{to: to}}} <- drain_mailbox(), do: to)
  end

  defp drain_mailbox(acc \\ []) do
    receive do
      message -> drain_mailbox([message | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
