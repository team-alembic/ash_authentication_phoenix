# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.PasswordResetTest do
  @moduledoc false

  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  require Ash.Query

  @endpoint AshAuthentication.Phoenix.Test.Endpoint

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  test "sign_in routes liveview renders the request password reset page", %{conn: conn} do
    conn = get(conn, "/reset")
    assert {:ok, view, _html} = live(conn)

    assert element(
             view,
             "div#user-password-request-password-reset-with-password-wrapper:not(.hidden)",
             "Request reset password link"
           )
           |> render()
  end

  test "reset_route routes liveview renders the password reset page", %{conn: conn} do
    conn = get(conn, "/password-reset/my_token_213")
    assert {:ok, _view, html} = live(conn)
    assert html =~ "Password reset"
  end

  test "reset_route routes liveview honours external gettext_fn", %{conn: conn} do
    # Translator stub at AshAuthentication.Phoenix.Test.Gettext.translate_auth
    conn = get(conn, "/vergessen/meine_wertmarke_213")
    assert {:ok, _view, html} = live(conn)
    refute html =~ "Password reset"
    assert html =~ "ever gonna"
  end

  test "reset_route routes liveview honours external gettext_backend", %{conn: conn} do
    # Translator stub at AshAuthentication.Phoenix.Test.Gettext
    conn = get(conn, "/vergessen_backend/meine_wertmarke_213")
    assert {:ok, _view, html} = live(conn)
    refute html =~ "Password reset"
    assert html =~ "ever gonna"
  end

  test "full password reset via sign_in and reset routes", %{conn: conn} do
    Example.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: "steffen@example.com",
      password: "so-secure!",
      password_confirmation: "so-secure!"
    })
    |> Ash.create!()

    assert_received(
      :sender_password_confirmation_fired,
      "user registration did not send confirmation email"
    )

    conn = get(conn, "/reset")
    assert {:ok, lv, _html} = live(conn)

    lv
    |> form("#user-password-request-password-reset-with-password-wrapper form", %{
      "user" => %{
        "email" => "steffen@example.com"
      }
    })
    |> render_submit()

    assert_received(
      {:sender_password_reset_request_fired, token},
      "request password reset action did not send email"
    )

    # Render again to process flash messages from components
    html = lv |> render()
    assert html =~ "reset instructions"

    conn = get(conn, "/password-reset/#{token}")
    assert {:ok, lv, _html} = live(conn)

    reset_form_data = %{
      "user" => %{
        "reset_token" => token,
        "password" => "much secret",
        "password_confirmation" => "much secret"
      }
    }

    # Submit once to validate and have `phx-trigger-action` activated
    lv
    |> form("form", reset_form_data)
    |> render_submit()

    conn =
      lv
      |> form("form", reset_form_data)
      |> follow_trigger_action(conn)

    refute conn.assigns[:failure_reason]
    assert conn.resp_body =~ "Success"
    assert conn.assigns[:current_user], "user not logged in after password change"
  end
end
