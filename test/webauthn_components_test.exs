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

  describe "sign-in page with multiple user types" do
    test "renders a divider between resource groups", %{conn: conn} do
      conn = get(conn, "/sign-in")
      assert {:ok, _view, html} = live(conn)

      # anon_user sorts before user, so the passkey-first strategies render
      # first, then a divider, then the User strategies.
      assert [_, after_anon] =
               String.split(html, "anon-user-webauthn-register-token-form", parts: 2)

      assert [between_groups, _] =
               String.split(after_anon, "user-webauthn-sign-in-form", parts: 2)

      assert between_groups =~ "border-t border-gray-300"
    end

    test "labels every group with its subject name, including the first", %{conn: conn} do
      conn = get(conn, "/sign-in")
      assert {:ok, _view, html} = live(conn)

      assert html =~ ~r|<span[^>]*>\s*Admin\s*</span>|
      assert html =~ ~r|<span[^>]*>\s*Anon user\s*</span>|
      assert html =~ ~r|<span[^>]*>\s*User\s*</span>|
    end

    test "per-resource webauthn paths link each user type to its own page", %{conn: conn} do
      conn = get(conn, "/sign-in-webauthn-multi")
      assert {:ok, _view, html} = live(conn)

      assert html =~ ~s(href="/webauthn")
      assert html =~ ~s(href="/webauthn-passkey-first")
    end

    test "the link-mode WebAuthn button is not wrapped in the dedicated page's card",
         %{conn: conn} do
      conn = get(conn, "/sign-in-webauthn")
      assert {:ok, _view, html} = live(conn)

      assert html =~ "Continue with WebAuthn"
      refute html =~ "max-w-sm lg:w-96 rounded-2xl"
    end
  end

  describe "passkey-first mode (require_identity? false)" do
    test "renders a display name input instead of an identity input", %{conn: conn} do
      conn = get(conn, "/webauthn-passkey-first")
      assert {:ok, _view, html} = live(conn)

      assert html =~ ~s(name="display_name")
      refute html =~ ~s(name="email")
    end

    test "the display name feeds the user descriptor pushed to the client", %{conn: conn} do
      conn = get(conn, "/webauthn-passkey-first")
      assert {:ok, view, _html} = live(conn)

      view
      |> form("#anon-user-webauthn-register-form", %{"display_name" => "Jane Doe"})
      |> render_submit()

      assert_push_event(view, "registration-challenge", %{
        user: %{id: user_id, name: "Jane Doe", displayName: "Jane Doe"}
      })

      # the server-minted handle: 32 random bytes, base64url without padding
      assert user_id |> Base.url_decode64!(padding: false) |> byte_size() == 32
    end

    test "the passkey name becomes the descriptor's account name", %{conn: conn} do
      conn = get(conn, "/webauthn-passkey-first")
      assert {:ok, view, _html} = live(conn)

      view
      |> form("#anon-user-webauthn-register-form", %{
        "display_name" => "Jane Doe",
        "key_name" => "My YubiKey"
      })
      |> render_submit()

      # `user.name` is what password managers show as the saved key's
      # username — the passkey name must be baked in before the ceremony.
      assert_push_event(view, "registration-challenge", %{
        user: %{name: "My YubiKey", displayName: "Jane Doe"}
      })
    end
  end

  describe "identity mode (require_identity? true)" do
    test "does not render a display name input", %{conn: conn} do
      conn = get(conn, "/webauthn")
      assert {:ok, _view, html} = live(conn)

      refute html =~ ~s(name="display_name")
    end
  end

  describe "registration ceremony options" do
    test "pushes spec-complete creation options", %{conn: conn} do
      conn = get(conn, "/webauthn")
      assert {:ok, view, _html} = live(conn)

      view
      |> form("#user-webauthn-register-form", %{
        "user" => %{"email" => "someone@example.com", "name" => "Someone"}
      })
      |> render_submit()

      assert_push_event(view, "registration-challenge", %{
        challenge: challenge,
        rp: %{id: "localhost", name: "AshAuthenticationPhoenix Dev"},
        user: %{id: user_id, name: "someone@example.com", displayName: "someone@example.com"},
        pubKeyCredParams: pub_key_cred_params,
        excludeCredentials: [],
        authenticatorSelection: %{
          userVerification: user_verification,
          residentKey: resident_key
        },
        extensions: %{credProps: true},
        attestation: _,
        timeout: timeout
      })

      assert {:ok, _} = Base.url_decode64(challenge, padding: false)
      assert user_id |> Base.url_decode64!(padding: false) |> byte_size() == 32
      assert %{type: "public-key", alg: -7} in pub_key_cred_params
      assert %{type: "public-key", alg: -257} in pub_key_cred_params
      assert user_verification
      assert resident_key
      assert is_integer(timeout)
    end
  end

  describe "authentication ceremony options" do
    test "pushes spec-complete request options", %{conn: conn} do
      conn = get(conn, "/webauthn")
      assert {:ok, view, _html} = live(conn)

      view
      |> form("#user-webauthn-sign-in-form")
      |> render_submit()

      assert_push_event(view, "authentication-challenge", %{
        challenge: challenge,
        rpId: "localhost",
        userVerification: _,
        timeout: _,
        allowCredentials: []
      })

      assert {:ok, _} = Base.url_decode64(challenge, padding: false)
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
