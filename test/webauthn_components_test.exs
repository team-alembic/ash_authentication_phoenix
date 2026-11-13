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
    test "mounts and renders the sign-in form", %{conn: conn} do
      conn = get(conn, "/webauthn")
      assert {:ok, _view, html} = live(conn)

      assert html =~ "Sign in with Passkey"
      refute html =~ ~s(id="user-webauthn-sign-in-wrapper" class="hidden")
    end

    test "renders the registration form hidden, behind a link", %{conn: conn} do
      # The page has no registration route, so the other form is on the page
      # and the link swaps the two in the browser.
      conn = get(conn, "/webauthn")
      assert {:ok, view, html} = live(conn)

      assert html =~ "Register with Passkey"
      assert html =~ ~s(id="user-webauthn-register-wrapper" class="hidden")
      assert view |> element("a[phx-click]", "Need an account?") |> has_element?()
    end

    test "does not show a Continue with WebAuthn link (it IS the webauthn page)", %{conn: conn} do
      conn = get(conn, "/webauthn")
      assert {:ok, _view, html} = live(conn)

      refute html =~ "Continue with WebAuthn"
    end
  end

  describe "one form at a time" do
    test "sign-in shows first, registration is hidden, and nothing divides them",
         %{conn: conn} do
      conn = get(conn, "/webauthn_test")
      assert {:ok, view, html} = live(conn)

      assert html =~ "Sign in with Passkey"
      refute html =~ ~s(id="user-webauthn-sign-in-wrapper" class="hidden")
      assert html =~ ~s(id="user-webauthn-register-wrapper" class="hidden")
      refute html =~ "user-webauthn-sign-in-divider"

      # Both hooks are mounted, so the toggle needs no round trip.
      assert has_element?(view, "[phx-hook='WebAuthnAuthenticationHook']")
      assert has_element?(view, "[phx-hook='WebAuthnRegistrationHook']")
    end

    test "the links toggle in the browser when there is no registration route",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webauthn_test")

      register_link = view |> element("a[phx-click]", "Need an account?") |> render()
      assert register_link =~ ~s(href="#")
      assert register_link =~ "user-webauthn-register-wrapper"
      assert register_link =~ "user-webauthn-sign-in-wrapper"

      sign_in_link = view |> element("a[phx-click]", "Already have an account?") |> render()
      assert sign_in_link =~ ~s(href="#")
    end

    test "live_action :register shows registration and hides sign-in", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/webauthn_test?live_action=register")

      assert html =~ ~s(id="user-webauthn-sign-in-wrapper" class="hidden")
      refute html =~ ~s(id="user-webauthn-register-wrapper" class="hidden")
    end

    test "with a register_path only the sign-in form is rendered, linking to it",
         %{conn: conn} do
      {:ok, view, html} = live(conn, "/webauthn_test?register_path=/join")

      assert html =~ "WebAuthnAuthenticationHook"
      refute html =~ "WebAuthnRegistrationHook"
      refute html =~ "Register with Passkey"

      link = view |> element("a[href='/join']", "Need an account?") |> render()
      assert link =~ ~s(data-phx-link="patch")
    end

    test "with a register_path, :register renders only registration, linking back",
         %{conn: conn} do
      {:ok, view, html} =
        live(conn, "/webauthn_test?register_path=/join&live_action=register")

      assert html =~ "WebAuthnRegistrationHook"
      refute html =~ "WebAuthnAuthenticationHook"
      refute html =~ "Sign in with Passkey"

      # `path` defaults to "/" on the test component.
      assert view |> element("a[href='/']", "Already have an account?") |> has_element?()
    end

    test "a nil link text drops the link", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/webauthn_test?overrides=quiet")

      refute html =~ "Need an account?"
      refute html =~ "Already have an account?"
    end

    test "renders WebAuthn support detection hook", %{conn: conn} do
      conn = get(conn, "/webauthn_test")
      assert {:ok, _view, html} = live(conn)

      assert html =~ "WebAuthnSupportHook"
    end
  end

  describe "on the sign-in route" do
    test "/sign-in renders the passkey sign-in form alone, with a link to /register",
         %{conn: conn} do
      conn = get(conn, "/sign-in")
      assert {:ok, view, html} = live(conn)

      assert html =~ "anon-user-webauthn-sign-in-form"
      refute html =~ "anon-user-webauthn-register"

      assert view
             |> element(~s(a[href="/register"]), "Need an account?")
             |> has_element?()
    end

    test "/register renders the passkey registration form alone, with a link to /sign-in",
         %{conn: conn} do
      conn = get(conn, "/register")
      assert {:ok, view, html} = live(conn)

      assert html =~ "anon-user-webauthn-register-form"
      refute html =~ "anon-user-webauthn-sign-in-form"

      assert view
             |> element(~s(a[href="/sign-in"]), "Already have an account?")
             |> has_element?()
    end
  end

  describe "the description under the heading" do
    test "each form explains itself in a sentence", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/webauthn_test")

      assert html =~
               ~s(<p class="text-sm text-gray-600 dark:text-gray-400 mb-4">Your browser or phone will ask you to confirm it is you.</p>)

      assert html =~ "A passkey takes the place of a password."
    end

    test "nil hides it, as it does the heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/webauthn_test?overrides=quiet")

      refute html =~ "Your browser or phone will ask you"
      refute html =~ "A passkey takes the place of a password."
      refute html =~ ~s(<p class="text-sm text-gray-600)
    end
  end

  describe "the strategy's enabled flags" do
    test "sign_in_enabled? false leaves the registration form, shown, with no link",
         %{conn: conn} do
      # Registration completes at the `sign_in_with_token` route, which the
      # strategy keeps while it verifies, so registration still stands.
      {:ok, _view, html} = live(conn, "/webauthn_test?variant=no-sign-in")

      refute html =~ "Sign in with Passkey"
      assert html =~ "Register with Passkey"
      refute html =~ ~s(id="user-webauthn-register-wrapper" class="hidden")
      refute html =~ "Already have an account?"
    end

    test "without sign-in or verification there is no token exchange, so neither form",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/webauthn_test?variant=no-exchange")

      refute html =~ "Sign in with Passkey"
      refute html =~ "Register with Passkey"
    end

    test "the second-factor configuration renders neither form", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/webauthn_test?variant=second-factor")

      refute html =~ "Sign in with Passkey"
      refute html =~ "Register with Passkey"
    end

    test "registration_enabled? false leaves only the sign-in form, with no link", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/webauthn_test?variant=no-register")

      assert html =~ "Sign in with Passkey"
      refute html =~ "Register with Passkey"
      refute html =~ "Need an account?"
    end
  end

  describe "sign-in page with multiple user types" do
    test "renders a divider between resource groups", %{conn: conn} do
      conn = get(conn, "/sign-in")
      assert {:ok, _view, html} = live(conn)

      # anon_user sorts before user, so the passkey-first strategies render
      # first, then a divider, then the User strategies.
      assert [_, after_anon] =
               String.split(html, "anon-user-webauthn-sign-in-token-form", parts: 2)

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

    test "omits authenticatorAttachment rather than sending null", %{conn: conn} do
      conn = get(conn, "/webauthn")
      assert {:ok, view, _html} = live(conn)

      view
      |> form("#user-webauthn-register-form", %{
        "user" => %{"email" => "someone@example.com", "name" => "Someone"}
      })
      |> render_submit()

      assert_push_event(view, "registration-challenge", %{authenticatorSelection: selection})

      # `null` is not a member of the AuthenticatorAttachment enum; the
      # absence of the key is how "no preference" is spelled.
      refute Map.has_key?(selection, :authenticatorAttachment)

      # The Level 1 spelling, for clients predating `residentKey`.
      assert selection.residentKey == :required
      assert selection.requireResidentKey == true
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

  describe "cross-device hints" do
    test "the member is absent when the strategy configures no hints", %{conn: conn} do
      conn = get(conn, "/webauthn")
      assert {:ok, view, _html} = live(conn)

      view
      |> form("#user-webauthn-sign-in-form")
      |> render_submit()

      assert_push_event(view, "authentication-challenge", options)

      # An empty sequence reads to some clients as "nothing is acceptable",
      # so "no preference" must be spelled by leaving the member out.
      refute Map.has_key?(options, :hints)
    end

    test "the strategy's hints are carried into the authentication options", %{conn: conn} do
      conn = get(conn, "/webauthn-passkey-first")
      assert {:ok, view, _html} = live(conn)

      view
      |> form("#anon-user-webauthn-sign-in-form")
      |> render_submit()

      # Hyphenated PublicKeyCredentialHint members, in the configured order of
      # preference — the DSL spells them as atoms.
      assert_push_event(view, "authentication-challenge", %{hints: ["hybrid", "security-key"]})
    end

    test "registration gets the hints too, so a phone can be enrolled", %{conn: conn} do
      conn = get(conn, "/webauthn-passkey-first")
      assert {:ok, view, _html} = live(conn)

      view
      |> form("#anon-user-webauthn-register-form", %{"display_name" => "Jane Doe"})
      |> render_submit()

      assert_push_event(view, "registration-challenge", %{hints: ["hybrid", "security-key"]})
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

  describe "the input placeholders" do
    # The mock strategy requires no identity, so the registration form asks
    # for a display name; the default overrides show the passkey name too.
    test "read their defaults without a translator", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/webauthn_test?live_action=register")

      assert html =~ ~r/id="user-webauthn-register-display-name"[^>]*placeholder="Jane Doe"/
      assert html =~ ~r/id="user-webauthn-register-key-name"[^>]*placeholder="My passkey"/
    end

    test "go through gettext_fn like the labels beside them", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/webauthn_test?live_action=register&gettext=stub")

      assert html =~
               ~r/id="user-webauthn-register-display-name"[^>]*placeholder="Never gonna give you up!"/

      assert html =~
               ~r/id="user-webauthn-register-key-name"[^>]*placeholder="Never gonna give you up!"/

      refute html =~ ~s(placeholder="Jane Doe")
      refute html =~ ~s(placeholder="My passkey")
    end
  end
end
