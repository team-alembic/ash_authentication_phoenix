# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.WebAuthnContextTest do
  @moduledoc """
  The Ash context a request carries (`Ash.PlugHelpers.set_context/2`)
  reaches the WebAuthn strategy from the sign-in and registration pages.

  `sign_in_route` puts the connection's context in the live session, and
  the forms hand it to every challenge and action call they make. The
  passkey-only test resource resolves its `rp_id` through a Secret that
  reports the context it is handed, which is how these tests see it.
  """

  use AshAuthentication.Phoenix.Test.ConnCase, async: false
  import ExUnit.CaptureLog

  alias AshAuthentication.Info
  alias AshAuthentication.Phoenix.Test.WebAuthnFixtures, as: Fixtures
  alias AshAuthentication.Phoenix.WebAuthn, as: PhoenixWebAuthn
  alias AshAuthentication.Strategy.WebAuthn.Actions
  alias Example.Accounts.WebAuthnRelyingParty, as: RelyingParty

  @moduletag :webauthn_strategy_required

  @context %{invitation_token: "join-us"}

  setup do
    RelyingParty.observe()
    {:ok, strategy: Info.strategy!(Example.Accounts.AnonUser, :webauthn)}
  end

  # What the test router's `put_test_context` plug puts on the connection,
  # as an application's own plug would with `Ash.PlugHelpers.set_context/2`.
  defp with_request_context(context) do
    Application.put_env(:ash_authentication_phoenix, :test_context, context)
    on_exit(fn -> Application.put_env(:ash_authentication_phoenix, :test_context, nil) end)
  end

  # Every resolution so far carried `expected` (plus the tenant the
  # strategy adds), and there was at least one.
  defp assert_resolved_with(expected) do
    contexts = RelyingParty.resolved_contexts()
    assert [_ | _] = contexts

    for context <- contexts do
      assert Map.delete(context, :tenant) == expected
      assert Map.has_key?(context, :tenant)
    end
  end

  defp register_user!(strategy) do
    {{:ok, user}, passkey} = Fixtures.register(strategy, %{})
    # The fixture's own ceremony resolved the relying party too.
    RelyingParty.resolved_contexts()
    {user, passkey}
  end

  describe "the sign-in page" do
    test "hands the request's context to the challenge, and signs in with it",
         %{conn: conn, strategy: strategy} do
      {_user, passkey} = register_user!(strategy)
      with_request_context(@context)

      {:ok, view, _html} = conn |> get("/sign-in") |> live()
      view |> form("#anon-user-webauthn-sign-in-form") |> render_submit()
      assert_push_event(view, "authentication-challenge", %{challenge: challenge})

      assert_resolved_with(@context)

      html =
        view
        |> element("#anon-user-webauthn-sign-in")
        |> render_hook(
          "authentication-assertion",
          Fixtures.assertion_event(strategy, passkey, challenge)
        )

      assert html =~ ~r/name="token" value="ey/
      refute html =~ "Authentication failed"
    end

    test "with no context on the connection the strategy gets an empty one",
         %{conn: conn} do
      {:ok, view, _html} = conn |> get("/sign-in") |> live()
      view |> form("#anon-user-webauthn-sign-in-form") |> render_submit()
      assert_push_event(view, "authentication-challenge", %{})

      assert_resolved_with(%{})
    end
  end

  describe "the registration page" do
    test "hands the request's context to the challenge, and registers with it",
         %{conn: conn, strategy: strategy} do
      with_request_context(@context)

      {:ok, view, _html} = conn |> get("/register") |> live()

      view
      |> form("#anon-user-webauthn-register-form", %{"display_name" => "Jane Doe"})
      |> render_submit()

      assert_push_event(view, "registration-challenge", %{challenge: challenge})

      assert_resolved_with(@context)

      {event, _passkey} = Fixtures.attestation_event(strategy, challenge)

      html =
        view
        |> element("#anon-user-webauthn-register")
        |> render_hook("registration-attestation", event)

      assert html =~ ~r/name="token" value="ey/
      refute html =~ "Registration failed"
    end
  end

  # The strategy's actions see the context too: the test resource refuses
  # to register or sign in when the request context says `should_fail`.
  describe "the actions" do
    test "the register action sees the request's context", %{conn: conn, strategy: strategy} do
      with_request_context(%{should_fail: true})

      {:ok, view, _html} = conn |> get("/register") |> live()

      view
      |> form("#anon-user-webauthn-register-form", %{"display_name" => "Jane Doe"})
      |> render_submit()

      assert_push_event(view, "registration-challenge", %{challenge: challenge})
      {event, _passkey} = Fixtures.attestation_event(strategy, challenge)

      # The form logs every refused registration; this one is expected.
      log =
        capture_log(fn ->
          html =
            view
            |> element("#anon-user-webauthn-register")
            |> render_hook("registration-attestation", event)

          send(self(), {:html, html})
        end)

      assert_received {:html, html}
      assert log =~ "I cant let you do that dave"
      assert html =~ "Registration failed"
      refute html =~ ~r/name="token" value="ey/
    end

    test "the sign-in action sees the request's context", %{conn: conn, strategy: strategy} do
      {_user, passkey} = register_user!(strategy)
      with_request_context(%{should_fail: true})

      {:ok, view, _html} = conn |> get("/sign-in") |> live()
      view |> form("#anon-user-webauthn-sign-in-form") |> render_submit()
      assert_push_event(view, "authentication-challenge", %{challenge: challenge})

      log =
        capture_log(fn ->
          html =
            view
            |> element("#anon-user-webauthn-sign-in")
            |> render_hook(
              "authentication-assertion",
              Fixtures.assertion_event(strategy, passkey, challenge)
            )

          send(self(), {:html, html})
        end)

      assert_received {:html, html}
      assert log =~ "I cant let you do that dave"
      assert html =~ "Authentication failed"
      refute html =~ ~r/name="token" value="ey/
    end
  end

  describe "the ceremony option builders" do
    test "resolve the relying party in the given context", %{strategy: strategy} do
      {:ok, challenge} = Actions.registration_challenge(strategy, nil)
      RelyingParty.resolved_contexts()

      descriptor = %{id: "aWQ", name: "Jane", displayName: "Jane Doe"}

      PhoenixWebAuthn.registration_options(strategy, challenge, nil, descriptor, [],
        context: @context
      )

      assert_resolved_with(@context)

      PhoenixWebAuthn.authentication_options(strategy, challenge, nil, [], context: @context)
      assert_resolved_with(@context)
    end

    test "treat a nil context as none", %{strategy: strategy} do
      {:ok, challenge} = Actions.registration_challenge(strategy, nil)
      RelyingParty.resolved_contexts()

      PhoenixWebAuthn.authentication_options(strategy, challenge, nil, [], context: nil)
      assert_resolved_with(%{})

      descriptor = %{id: "aWQ", name: "Jane", displayName: "Jane Doe"}
      PhoenixWebAuthn.registration_options(strategy, challenge, nil, descriptor, [])
      assert_resolved_with(%{})
    end
  end
end
