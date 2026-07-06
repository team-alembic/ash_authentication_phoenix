# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.WebAuthnComponentsTest do
  @moduledoc false

  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint AshAuthentication.Phoenix.Test.Endpoint

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  # These tests require the AshAuthentication.Strategy.WebAuthn struct and protocol
  # implementation to be available. Skip until the ash_authentication WebAuthn strategy
  # is implemented.
  @moduletag :webauthn_strategy_required

  describe "WebAuthn link mode (webauthn_path set)" do
    test "renders a link instead of the full form", %{conn: conn} do
      conn = get(conn, "/webauthn_link_test")
      assert {:ok, _view, html} = live(conn)

      assert html =~ "Continue with WebAuthn"
      refute html =~ "Sign in with Passkey"
      refute html =~ "Register with Passkey"
    end

    test "the link points to the webauthn_path", %{conn: conn} do
      conn = get(conn, "/webauthn_link_test")
      assert {:ok, view, _html} = live(conn)

      assert element(view, "a[href='/webauthn']") |> render() =~ "Continue with WebAuthn"
    end
  end

  describe "WebAuthnLive dedicated page" do
    test "mounts and renders sign-in form", %{conn: conn} do
      conn = get(conn, "/webauthn")
      assert {:ok, _view, html} = live(conn)

      assert html =~ "Sign in with Passkey"
    end

    test "renders registration form", %{conn: conn} do
      conn = get(conn, "/webauthn")
      assert {:ok, _view, html} = live(conn)

      assert html =~ "Register with Passkey"
    end

    test "does not show a Continue with WebAuthn link (it IS the webauthn page)", %{conn: conn} do
      conn = get(conn, "/webauthn")
      assert {:ok, _view, html} = live(conn)

      refute html =~ "Continue with WebAuthn"
    end
  end

  describe "WebAuthn top-level component" do
    test "renders both forms (no toggle, always visible)", %{conn: conn} do
      conn = get(conn, "/webauthn_test")
      assert {:ok, view, _html} = live(conn)

      # Both forms are always rendered side by side
      assert element(view, "[phx-hook='WebAuthnAuthenticationHook']") |> render()
      assert element(view, "[phx-hook='WebAuthnRegistrationHook']") |> render()
    end

    test "renders sign-in button", %{conn: conn} do
      conn = get(conn, "/webauthn_test")
      assert {:ok, _view, html} = live(conn)

      assert html =~ "Sign in with Passkey"
    end

    test "renders an 'or' divider between sign-in and registration", %{conn: conn} do
      conn = get(conn, "/webauthn_test")
      assert {:ok, _view, html} = live(conn)

      assert html =~ "or"
    end

    test "renders register button in registration form", %{conn: conn} do
      conn = get(conn, "/webauthn_test")
      assert {:ok, _view, html} = live(conn)

      assert html =~ "Register with Passkey"
    end

    test "renders WebAuthn support detection hook", %{conn: conn} do
      conn = get(conn, "/webauthn_test")
      assert {:ok, _view, html} = live(conn)

      assert html =~ "WebAuthnSupportHook"
    end
  end

  describe "registration form custom fields" do
    test "renders inputs for register_action_accept fields", %{conn: conn} do
      conn = get(conn, "/webauthn")
      assert {:ok, _view, html} = live(conn)

      assert html =~ ~s(name="user[email]")
      assert html =~ ~s(name="user[name]")
    end

    test "custom fields are validated by the action's rules before the ceremony starts",
         %{conn: conn} do
      conn = get(conn, "/webauthn")
      assert {:ok, view, _html} = live(conn)

      html =
        view
        |> form("#user-webauthn-register-form", %{
          "user" => %{"email" => "someone@example.com", "name" => "x"}
        })
        |> render_submit()

      # min_length: 2 on the :name attribute
      assert html =~ "greater than or equal to 2"
    end

    test "valid custom fields don't block the ceremony", %{conn: conn} do
      conn = get(conn, "/webauthn")
      assert {:ok, view, _html} = live(conn)

      html =
        view
        |> form("#user-webauthn-register-form", %{
          "user" => %{"email" => "someone@example.com", "name" => "Someone"}
        })
        |> render_submit()

      refute html =~ "greater than or equal to 2"
    end
  end
end
