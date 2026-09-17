# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.SignInTest do
  @moduledoc false

  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

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

  test "sign_in routes allow a user to sign in", %{conn: conn} do
    register_user("zach@example.com")

    conn = get(conn, "/sign-in")
    assert {:ok, lv, _html} = live(conn)

    result = submit_sign_in(lv, "zach@example.com")

    assert hand_off_urls(lv, result) == ["/auth/user/password/sign_in_with_token"]
  end

  test "sign_in hands the sign in token over without placing it in a URL", %{conn: conn} do
    register_user("token@example.com")

    conn = get(conn, "/sign-in")
    assert {:ok, lv, _html} = live(conn)

    result = submit_sign_in(lv, "token@example.com")

    for url <- hand_off_urls(lv, result) do
      refute url =~ @jwt, "the sign in token was placed in a URL: #{url}"
    end

    assert [token] = hand_off_tokens(lv, result)
    assert token =~ @jwt
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

  test "password visibility toggle is hidden by default", %{conn: conn} do
    conn = get(conn, "/sign-in")
    assert {:ok, _view, html} = live(conn)

    refute html =~ "-show-label"
  end

  test "password visibility toggle is rendered when enabled via override", %{conn: conn} do
    conn = get(conn, "/sign-in-password-toggle")
    assert {:ok, view, html} = live(conn)

    assert html =~ "-show-label"
    assert has_element?(view, "button[phx-click] svg[aria-hidden=\"true\"]")
    assert has_element?(view, "button span[id$=\"-show-label\"] span.sr-only", "Show password")
    assert has_element?(view, "button span[id$=\"-hide-label\"] span.sr-only", "Hide password")
  end

  test "register page shows a single toggle that controls both password fields", %{conn: conn} do
    conn = get(conn, "/register-password-toggle")
    assert {:ok, view, html} = live(conn)

    assert has_element?(view, "button span[id$=\"-show-label\"]")

    refute html =~ "password_confirmation-show-label"

    assert html =~ "#user-password-register-with-password_password_confirmation"
  end

  describe "development mailbox link" do
    setup do
      on_exit(fn -> Application.delete_env(:ash_authentication, :dev_mailbox_path) end)
    end

    test "is not rendered when no path is configured", %{conn: conn} do
      Application.delete_env(:ash_authentication, :dev_mailbox_path)

      conn = get(conn, "/sign-in")
      assert {:ok, _view, html} = live(conn)

      refute html =~ "development mailbox"
    end

    test "links to the configured path", %{conn: conn} do
      Application.put_env(:ash_authentication, :dev_mailbox_path, "/dev/mailbox")

      conn = get(conn, "/sign-in")
      assert {:ok, view, _html} = live(conn)

      assert view
             |> element(~s{a[href="/dev/mailbox"]})
             |> render() =~ "View sent emails in the development mailbox"
    end

    test "is rendered on the register page too", %{conn: conn} do
      Application.put_env(:ash_authentication, :dev_mailbox_path, "/mail")

      conn = get(conn, "/register")
      assert {:ok, view, _html} = live(conn)

      assert has_element?(view, ~s{a[href="/mail"]})
    end
  end

  test "sign_in liveview honours filter_strategy override", %{conn: conn} do
    conn = get(conn, "/sign-in-filtered")

    assert {:ok, _, html} = live(conn)

    # password strategy still visible
    assert html =~ "sign-in-with-password"

    # invite strategy is hidden
    refute html =~ "invite-request-invite"
  end

  describe "the sign in token hand-off form" do
    test "names the token as a top level parameter" do
      html = render_hand_off(%{token: "a-sign-in-token"})

      assert html =~ ~s{name="token"}
      assert html =~ ~s{value="a-sign-in-token"}
      refute html =~ ~s{name="user[token]"}
    end

    test "posts to the sign_in_with_token route with no query string" do
      html = render_hand_off(%{token: "a-sign-in-token"})

      assert html =~ ~s{action="/auth/user/password/sign_in_with_token"}
      assert html =~ ~s{method="post"}
    end

    test "carries remember_me as a top level parameter when it is set" do
      html = render_hand_off(%{token: "a-sign-in-token", remember_me: "true"})

      assert html =~ ~s{name="remember_me"}
      refute html =~ ~s{name="user[remember_me]"}
    end

    test "omits remember_me when it is not set" do
      html = render_hand_off(%{token: "a-sign-in-token"})

      refute html =~ ~s{name="remember_me"}
    end

    test "does not trigger before the user has signed in" do
      refute render_hand_off(nil) =~ "phx-trigger-action"
    end
  end

  defp render_hand_off(sign_in_token_params) do
    render_component(AshAuthentication.Phoenix.Components.Password.SignInForm, %{
      id: "sign-in-form",
      strategy: AshAuthentication.Info.strategy!(Example.Accounts.User, :password),
      auth_routes_prefix: "/auth",
      sign_in_token_params: sign_in_token_params
    })
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

  defp submit_sign_in(lv, email) do
    lv
    |> form("#user-password-sign-in-with-password", %{
      "user" => %{"email" => email, "password" => "so-secure!"}
    })
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
