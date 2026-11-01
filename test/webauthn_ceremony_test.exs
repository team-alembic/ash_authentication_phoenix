# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.WebAuthnCeremonyTest do
  @moduledoc false

  use AshAuthentication.Phoenix.Test.ConnCase, async: false
  import ExUnit.CaptureLog

  alias AshAuthentication.Info
  alias AshAuthentication.Phoenix.Test.WebAuthnFixtures, as: Fixtures

  @moduletag :webauthn_strategy_required

  setup do
    {:ok, strategy: Info.strategy!(Example.Accounts.User, :webauthn)}
  end

  # A user registered through the strategy itself, holding one passkey whose
  # handle the strategy stored on the credential.
  defp register_user!(strategy) do
    email = "passkey-#{System.unique_integer([:positive])}@example.com"

    {{:ok, user}, passkey} =
      Fixtures.register(strategy, %{"email" => email, "name" => "Someone"})

    {user, passkey}
  end

  # What `load_from_session` and `LiveSession` read: the User resource keys
  # its session by `jti:subject`.
  defp signed_in(conn, user) do
    init_test_session(conn, %{"user" => "test-jti:" <> AshAuthentication.user_to_subject(user)})
  end

  defp start_sign_in(view) do
    view |> form("#user-webauthn-sign-in-form") |> render_submit()
    assert_push_event(view, "authentication-challenge", %{challenge: challenge})
    challenge
  end

  # Pushes the assertion the way the `WebAuthnAuthenticationHook` does: to
  # the component whose root element carries the hook.
  defp assert_assertion(view, hook_id, event) do
    view |> element(hook_id) |> render_hook("authentication-assertion", event)
  end

  describe "sign-in" do
    test "an assertion returning the credential's own user handle signs in",
         %{conn: conn, strategy: strategy} do
      {_user, passkey} = register_user!(strategy)

      {:ok, view, _html} = live(conn, "/webauthn")
      challenge = start_sign_in(view)

      html =
        assert_assertion(
          view,
          "#user-webauthn-sign-in",
          Fixtures.assertion_event(strategy, passkey, challenge)
        )

      # Success fills the hidden token form that is then trigger-submitted
      # to `sign_in_with_token`.
      assert html =~ ~r/name="token" value="ey/
      refute html =~ "Authentication failed"
    end

    test "an assertion returning another account's user handle is refused",
         %{conn: conn, strategy: strategy} do
      {_user, passkey} = register_user!(strategy)
      {_other_user, other_passkey} = register_user!(strategy)

      {:ok, view, _html} = live(conn, "/webauthn")
      challenge = start_sign_in(view)

      event =
        Fixtures.assertion_event(strategy, passkey, challenge,
          user_handle: other_passkey.user_handle
        )

      # The form logs every refused sign-in; this one is expected.
      log =
        capture_log(fn ->
          html = assert_assertion(view, "#user-webauthn-sign-in", event)
          send(self(), {:html, html})
        end)

      assert_received {:html, html}
      assert log =~ "user handle does not match the credential's owner"
      assert html =~ "Authentication failed"
      refute html =~ ~r/name="token" value="ey/
    end

    test "the sign-in challenge lists no credentials", %{conn: conn, strategy: strategy} do
      {_user, _passkey} = register_user!(strategy)

      {:ok, view, _html} = live(conn, "/webauthn")
      view |> form("#user-webauthn-sign-in-form") |> render_submit()

      assert_push_event(view, "authentication-challenge", %{allowCredentials: []})
    end
  end

  describe "second-factor verify (step-up)" do
    test "an assertion returning the credential's own user handle verifies",
         %{conn: conn, strategy: strategy} do
      {user, passkey} = register_user!(strategy)

      {:ok, view, _html} = conn |> signed_in(user) |> live("/webauthn-verify")
      view |> form("#webauthn_verify-form") |> render_submit()

      # The caller is authenticated, so the actor's own credentials are
      # listed, which is what lets a non-discoverable key answer here.
      assert_push_event(view, "authentication-challenge", %{
        challenge: challenge,
        allowCredentials: [%{id: _}]
      })

      html =
        assert_assertion(
          view,
          "#webauthn_verify",
          Fixtures.assertion_event(strategy, passkey, challenge)
        )

      assert html =~ ~r/name="token" value="ey/
      refute html =~ "Verification failed"
    end

    test "an assertion returning another account's user handle is refused",
         %{conn: conn, strategy: strategy} do
      {user, passkey} = register_user!(strategy)
      {_other_user, other_passkey} = register_user!(strategy)

      {:ok, view, _html} = conn |> signed_in(user) |> live("/webauthn-verify")
      view |> form("#webauthn_verify-form") |> render_submit()
      assert_push_event(view, "authentication-challenge", %{challenge: challenge})

      html =
        assert_assertion(
          view,
          "#webauthn_verify",
          Fixtures.assertion_event(strategy, passkey, challenge,
            user_handle: other_passkey.user_handle
          )
        )

      assert html =~ "Verification failed"
      refute html =~ ~r/name="token" value="ey/
    end
  end
end
