# SPDX-FileCopyrightText: 2024 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.TotpComponentsTest do
  @moduledoc false

  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint AshAuthentication.Phoenix.Test.Endpoint

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  describe "TOTP sign-in form" do
    test "renders TOTP sign-in form on sign-in page", %{conn: conn} do
      conn = get(conn, "/sign-in")
      assert {:ok, _view, html} = live(conn)

      assert html =~ "user-totp-sign-in-with-totp"
      assert html =~ "email"
      assert html =~ "code"
    end

    test "renders identity field for TOTP sign-in", %{conn: conn} do
      conn = get(conn, "/sign-in")
      assert {:ok, view, _html} = live(conn)

      assert has_element?(view, "#user-totp-sign-in-with-totp_email")
    end

    test "renders code field for TOTP sign-in", %{conn: conn} do
      conn = get(conn, "/sign-in")
      assert {:ok, view, _html} = live(conn)

      assert has_element?(view, "#user-totp-sign-in-with-totp_code")
    end

    test "validates form on change", %{conn: conn} do
      conn = get(conn, "/sign-in")
      assert {:ok, view, _html} = live(conn)

      view
      |> form("#user-totp-sign-in-with-totp", %{
        "user" => %{"email" => "test@example.com", "code" => "123456"}
      })
      |> render_change()

      assert has_element?(view, "#user-totp-sign-in-with-totp")
    end

    test "TOTP sign-in form has correct action URL", %{conn: conn} do
      conn = get(conn, "/sign-in")
      assert {:ok, _view, html} = live(conn)

      assert html =~ ~s(action="/auth/user/totp/sign_in")
    end

    test "TOTP sign-in form validates and submits", %{conn: conn} do
      conn = get(conn, "/sign-in")
      assert {:ok, view, _html} = live(conn)

      view
      |> form("#user-totp-sign-in-with-totp", %{
        "user" => %{
          "email" => "test@example.com",
          "code" => "123456"
        }
      })
      |> render_submit()

      # Form should still render (not crash) even with invalid credentials
      assert has_element?(view, "#user-totp-sign-in-with-totp")
    end
  end

  describe "TOTP setup form" do
    test "does NOT render setup form on sign-in page by default", %{conn: conn} do
      # Setup form should be on a dedicated page for authenticated users, not on sign-in page
      conn = get(conn, "/sign-in")
      assert {:ok, _view, html} = live(conn)

      refute html =~ "user-totp-setup-with-totp-wrapper"
    end

    test "does NOT show setup toggle on sign-in page by default", %{conn: conn} do
      conn = get(conn, "/sign-in")
      assert {:ok, _view, html} = live(conn)

      refute html =~ "Need to set up authenticator?"
    end
  end
end
