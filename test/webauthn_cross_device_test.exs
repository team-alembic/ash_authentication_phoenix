# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.WebAuthnCrossDeviceTest do
  @moduledoc """
  The secondary button on every ceremony component — "Use a phone or
  tablet" or "Use a passkey on this device", never both — the hints it
  requests, the addressing of pushed options, and the ceremony timeout the
  components keep for themselves.
  """

  use AshAuthentication.Phoenix.Test.ConnCase, async: false

  alias AshAuthentication.Info
  alias AshAuthentication.Phoenix.Test.WebAuthnFixtures, as: Fixtures

  @moduletag :webauthn_strategy_required

  @phone "Use a phone or tablet"
  @this_device "Use a passkey on this device"

  # Submits `form` the way a click on its secondary button does: the button
  # is the submitter, so its `hints=...` value rides along.
  defp submit_with_secondary(form) do
    form |> put_submitter("button[name=hints]") |> render_submit()
  end

  defp register_user!(strategy) do
    email = "cross-device-#{System.unique_integer([:positive])}@example.com"

    {{:ok, user}, passkey} =
      Fixtures.register(strategy, %{"email" => email, "name" => "Someone"})

    {user, passkey}
  end

  defp signed_in(conn, user) do
    init_test_session(conn, %{
      "user" => "test-jti:" <> AshAuthentication.user_to_subject(user),
      "user_metadata" => %{token: user.__metadata__.token}
    })
  end

  describe "which secondary button the sign-in and registration forms offer" do
    test "this device, when the strategy leads with :hybrid and allows the override",
         %{conn: conn} do
      # AnonUser: `hints [:hybrid, :security_key]`, `allow_hint_override? true`.
      # The main button already opens on the phone's QR code, so asking for
      # the phone again would change nothing.
      {:ok, _view, html} = live(conn, "/webauthn-passkey-first")

      assert html =~ @this_device
      assert html =~ ~s(name="hints" value="client-device")
      refute html =~ @phone
    end

    test "the phone, when the override is allowed and nothing is configured", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/webauthn_test?variant=override")

      assert html =~ @phone
      assert html =~ ~s(name="hints" value="hybrid")
      refute html =~ @this_device
    end

    test "the phone, when the override is allowed and the hints lead elsewhere",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/webauthn_test?variant=security-key-first")

      assert html =~ @phone
      refute html =~ @this_device
    end

    test "nothing without the override, even with :hybrid offered", %{conn: conn} do
      # The request would be ignored, so the button would do what the main
      # one does.
      {:ok, _view, html} = live(conn, "/webauthn_test?variant=hybrid")

      refute html =~ ~s(name="hints")
      refute html =~ @phone
      refute html =~ @this_device
    end

    test "nothing when the strategy neither offers :hybrid nor allows a request",
         %{conn: conn} do
      # User: no hints, no override.
      {:ok, _view, html} = live(conn, "/webauthn")

      refute html =~ ~s(name="hints")
    end

    test "nothing for platform authenticators only", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/webauthn_test?variant=platform")

      refute html =~ ~s(name="hints")
    end

    test "one secondary button per form, never two", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webauthn-passkey-first")

      for form <- ["#anon-user-webauthn-sign-in-form", "#anon-user-webauthn-register-form"] do
        html = view |> element(form) |> render()
        assert length(String.split(html, ~s(name="hints"))) == 2, "#{form} has two"
      end
    end
  end

  describe "the hints the secondary button requests" do
    test "this device asks for the client-device hint alone on sign-in", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webauthn-passkey-first")

      view |> form("#anon-user-webauthn-sign-in-form") |> submit_with_secondary()

      assert_push_event(view, "authentication-challenge", %{hints: ["client-device"]})
    end

    test "the plain button keeps the configured hints on sign-in", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webauthn-passkey-first")

      view |> form("#anon-user-webauthn-sign-in-form") |> render_submit()

      assert_push_event(view, "authentication-challenge", %{hints: ["hybrid", "security-key"]})
    end

    test "this device asks for the client-device hint alone on registration", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webauthn-passkey-first")

      view
      |> form("#anon-user-webauthn-register-form", %{"display_name" => "Jane Doe"})
      |> submit_with_secondary()

      assert_push_event(view, "registration-challenge", %{hints: ["client-device"]})
    end

    test "the phone asks for the hybrid hint alone, on a strategy that configures none",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webauthn_test?variant=override")

      view |> form("#user-webauthn-sign-in-form") |> render_submit()
      assert_push_event(view, "authentication-challenge", plain)
      refute Map.has_key?(plain, :hints)

      # A ceremony is in flight on that view, so the phone goes on a fresh one.
      {:ok, view, _html} = live(conn, "/webauthn_test?variant=override")
      view |> form("#user-webauthn-sign-in-form") |> submit_with_secondary()

      assert_push_event(view, "authentication-challenge", %{hints: ["hybrid"]})
    end

    test "the phone asks for the hybrid hint alone when the hints lead elsewhere",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webauthn_test?variant=security-key-first")

      view |> form("#user-webauthn-sign-in-form") |> submit_with_secondary()

      assert_push_event(view, "authentication-challenge", %{hints: ["hybrid"]})
    end

    test "a request is ignored when the strategy does not allow the override", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webauthn_test?variant=hybrid")

      # No button to click, so straight to the event, as a tampered client
      # would send it.
      view
      |> element("#user-webauthn-sign-in")
      |> render_hook("authenticate", %{"hints" => "client-device"})

      # The configured hints stand, exactly as the Plug endpoints treat a
      # `?hints=` parameter the strategy has not opened up.
      assert_push_event(view, "authentication-challenge", %{hints: ["hybrid", "security-key"]})
    end

    test "unknown hints in a request are dropped", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webauthn-passkey-first")

      view
      |> element("#anon-user-webauthn-sign-in")
      |> render_hook("authenticate", %{"hints" => "telepathy, hybrid"})

      assert_push_event(view, "authentication-challenge", %{hints: ["hybrid"]})
    end
  end

  describe "the add-passkey form" do
    setup do
      {:ok, strategy: Info.strategy!(Example.Accounts.User, :webauthn)}
    end

    test "offers this device when the strategy leads with :hybrid",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, html} = conn |> signed_in(user) |> live("/webauthn-manage/hybrid")
      assert html =~ @this_device
      refute html =~ @phone

      view |> form("#manage-add-key-form") |> submit_with_secondary()

      assert_push_event(view, "registration-challenge", %{hints: ["client-device"]})
    end

    test "offers the phone when the client may choose and nothing leads",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, html} = conn |> signed_in(user) |> live("/webauthn-manage/override")
      assert html =~ @phone
      refute html =~ @this_device

      view |> form("#manage-add-key-form") |> submit_with_secondary()

      assert_push_event(view, "registration-challenge", %{hints: ["hybrid"]})
    end

    test "offers nothing otherwise", %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, _view, html} = conn |> signed_in(user) |> live("/webauthn-setup")

      refute html =~ ~s(name="hints")
    end
  end

  describe "the second-factor verify form" do
    setup do
      {:ok, strategy: Info.strategy!(Example.Accounts.User, :webauthn)}
    end

    test "offers this device when the strategy leads with :hybrid",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, html} = conn |> signed_in(user) |> live("/webauthn-verify-variant/hybrid")
      assert html =~ @this_device
      refute html =~ @phone

      view |> form("#verify-form") |> submit_with_secondary()

      # The actor's own credentials are still listed; only the hints change.
      assert_push_event(view, "authentication-challenge", %{
        hints: ["client-device"],
        allowCredentials: [%{id: _}]
      })
    end

    test "offers the phone when the client may choose and nothing leads",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, html} = conn |> signed_in(user) |> live("/webauthn-verify-variant/override")
      assert html =~ @phone
      refute html =~ @this_device

      view |> form("#verify-form") |> submit_with_secondary()

      assert_push_event(view, "authentication-challenge", %{hints: ["hybrid"]})
    end

    test "offers nothing otherwise", %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, _view, html} = conn |> signed_in(user) |> live("/webauthn-verify")

      refute html =~ ~s(name="hints")
    end
  end

  describe "pushed options are addressed to one hook" do
    setup do
      {:ok, strategy: Info.strategy!(Example.Accounts.User, :webauthn)}
    end

    test "the sign-in and registration forms address their own root elements",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webauthn")

      view |> form("#user-webauthn-sign-in-form") |> render_submit()
      assert_push_event(view, "authentication-challenge", %{target: "user-webauthn-sign-in"})

      view
      |> form("#user-webauthn-register-form", %{
        "user" => %{"email" => "someone@example.com", "name" => "Someone"}
      })
      |> render_submit()

      assert_push_event(view, "registration-challenge", %{target: "user-webauthn-register"})
    end

    test "the add-passkey form addresses its hook element, not the panel",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, _html} = conn |> signed_in(user) |> live("/webauthn-setup")
      view |> form("#webauthn_setup-add-key-form") |> render_submit()

      assert_push_event(view, "registration-challenge", %{target: "webauthn_setup-add-key"})
    end

    test "the verify form addresses its root element", %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, _html} = conn |> signed_in(user) |> live("/webauthn-verify")
      view |> form("#webauthn_verify-form") |> render_submit()

      assert_push_event(view, "authentication-challenge", %{target: "webauthn_verify"})
    end
  end

  describe "the ceremony timeout is the strategy's" do
    setup do
      {:ok, strategy: Info.strategy!(Example.Accounts.User, :webauthn)}
    end

    test "sign-in gives up after the strategy's timeout and refuses a late assertion",
         %{conn: conn, strategy: strategy} do
      {_user, passkey} = register_user!(strategy)

      {:ok, view, _html} = live(conn, "/webauthn_test?variant=quick")
      view |> form("#user-webauthn-sign-in-form") |> render_submit()
      assert_push_event(view, "authentication-challenge", %{challenge: challenge, timeout: 100})

      Process.sleep(200)
      assert render(view) =~ "Authentication timed out"

      # The browser answers after the deadline: the stale challenge is gone
      # and the strategy is not consulted.
      html =
        view
        |> element("#user-webauthn-sign-in")
        |> render_hook(
          "authentication-assertion",
          Fixtures.assertion_event(strategy, passkey, challenge)
        )

      assert html =~ "sign-in request has expired"
      refute html =~ ~r/name="token" value="ey/
    end

    test "registration gives up after the strategy's timeout", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webauthn_test?variant=quick")

      # The mock strategy requires no identity, so the form asks for a name.
      view
      |> form("#user-webauthn-register-form", %{"display_name" => "Someone"})
      |> render_submit()

      assert_push_event(view, "registration-challenge", %{timeout: 100})

      Process.sleep(200)
      assert render(view) =~ "Registration timed out"
    end

    test "a ceremony the browser already ended is not timed out later", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webauthn_test?variant=quick")
      view |> form("#user-webauthn-sign-in-form") |> render_submit()
      assert_push_event(view, "authentication-challenge", %{challenge: _})

      view
      |> element("#user-webauthn-sign-in")
      |> render_hook("authentication-error", %{"name" => "NotAllowedError", "message" => "no"})

      Process.sleep(200)
      html = render(view)

      assert html =~ "cancelled or not allowed"
      refute html =~ "timed out"
    end

    test "adding a passkey gives up after the strategy's timeout",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, _html} = conn |> signed_in(user) |> live("/webauthn-manage/quick")
      view |> form("#manage-add-key-form") |> render_submit()
      assert_push_event(view, "registration-challenge", %{timeout: 100})

      Process.sleep(200)
      html = render(view)

      assert html =~ "Adding the passkey timed out"
      refute html =~ "disabled"
    end

    test "verify gives up after the strategy's timeout", %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, _html} = conn |> signed_in(user) |> live("/webauthn-verify-variant/quick")
      view |> form("#verify-form") |> render_submit()
      assert_push_event(view, "authentication-challenge", %{timeout: 100})

      Process.sleep(200)
      assert render(view) =~ "Verification timed out"
    end
  end
end
