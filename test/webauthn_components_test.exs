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

  describe "WebAuthn top-level component" do
    test "renders the sign-in form by default", %{conn: conn} do
      conn = get(conn, "/webauthn_test")
      assert {:ok, view, _html} = live(conn)

      # Authentication form should be visible
      assert element(view, "[id$='-sign-in-wrapper']:not(.hidden)")
             |> render()

      # Registration form should be hidden by default
      assert element(view, "[id$='-register-wrapper'].hidden")
             |> render()
    end

    test "renders sign-in button", %{conn: conn} do
      conn = get(conn, "/webauthn_test")
      assert {:ok, _view, html} = live(conn)

      assert html =~ "Sign in with Passkey"
    end

    test "renders toggle to registration", %{conn: conn} do
      conn = get(conn, "/webauthn_test")
      assert {:ok, _view, html} = live(conn)

      assert html =~ "New here? Register a passkey"
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
end
