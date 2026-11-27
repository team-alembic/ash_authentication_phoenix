# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.WebAuthnSecondFactorFlowTest do
  @moduledoc """
  The second-factor flow end to end, on a resource configured the way
  `--mode 2fa` writes it (`Example.Accounts.Member`: password primary,
  WebAuthn with registration and sign-in off).

  The strategy has no sign-in, yet `verify` answers with a short-lived
  token that only `sign_in_with_token` turns into a session, so that
  exchange must exist for the verify page to complete. The resource's
  subject is `member`, so the pages must also find the signed-in record
  under `current_member`.
  """

  use AshAuthentication.Phoenix.Test.ConnCase, async: false

  alias AshAuthentication.{Info, Strategy}
  alias AshAuthentication.Phoenix.Test.WebAuthnFixtures, as: Fixtures
  alias AshAuthentication.Strategy.WebAuthn

  @moduletag :webauthn_strategy_required

  @password "second.factor.secret"

  setup do
    {:ok,
     strategy: Info.strategy!(Example.Accounts.Member, :webauthn),
     password: Info.strategy!(Example.Accounts.Member, :password)}
  end

  # A member registered with a password, through the password strategy's
  # own register action.
  defp register_member!(password_strategy) do
    email = "member-#{System.unique_integer([:positive])}@example.com"

    {:ok, member} =
      Strategy.action(
        password_strategy,
        :register,
        %{
          "email" => email,
          "password" => @password,
          "password_confirmation" => @password
        },
        []
      )

    {member, email}
  end

  # The primary factor: a password sign-in through the auth controller,
  # which stores the member in the session as the generated controller does
  # before sending them on to the verify page. Returns the conn, which now
  # carries the session, and the token the controller received.
  defp sign_in_with_password(conn, email) do
    conn =
      post(conn, "/member-auth/member/password/sign_in", %{
        "member" => %{"email" => email, "password" => @password}
      })

    assert html_response(conn, 200) =~ "Success"
    assert get_session(conn, "member")

    {conn, conn.assigns.current_user.__metadata__.token}
  end

  # Enrols a passkey on the member's setup page, as the browser would.
  defp enrol_passkey(conn, strategy) do
    {:ok, view, html} = live(conn, "/member/webauthn-setup")
    refute html =~ "must be signed in"

    view
    |> form("#webauthn_setup-add-key-form", %{"key_name" => "Phone"})
    |> render_submit()

    assert_push_event(view, "registration-challenge", %{challenge: challenge})
    {event, passkey} = Fixtures.attestation_event(strategy, challenge)

    html =
      view |> element("#webauthn_setup-add-key") |> render_hook("registration-attestation", event)

    assert html =~ "Phone"
    refute html =~ "Failed to register"

    passkey
  end

  # The hidden token form the verify page trigger-submits after a
  # successful assertion: its action and its inputs.
  defp token_form(html) do
    form =
      html
      |> Floki.parse_fragment!()
      |> Floki.find("form[phx-trigger-action]")

    params =
      for input <- Floki.find(form, "input"),
          into: %{},
          do: {Floki.attribute(input, "name") |> hd(), Floki.attribute(input, "value") |> hd()}

    {form |> Floki.attribute("action") |> hd(), params}
  end

  defp verify(view, strategy, passkey) do
    view |> form("#webauthn_verify-form") |> render_submit()

    assert_push_event(view, "authentication-challenge", %{
      challenge: challenge,
      allowCredentials: [%{id: _}]
    })

    view
    |> element("#webauthn_verify")
    |> render_hook(
      "authentication-assertion",
      Fixtures.assertion_event(strategy, passkey, challenge)
    )
  end

  describe "the strategy --mode 2fa writes" do
    test "keeps the token exchange although it cannot sign in", %{strategy: strategy} do
      refute strategy.sign_in_enabled?
      refute strategy.registration_enabled?
      assert strategy.verify_enabled?
      assert WebAuthn.sign_in_with_token_enabled?(strategy)
      assert :sign_in_with_token in Strategy.phases(strategy)
    end
  end

  describe "password, then passkey" do
    test "verifies the token the primary sign-in issued and exchanges it for a verified session",
         %{conn: conn, strategy: strategy, password: password} do
      {_member, email} = register_member!(password)
      {conn, token} = sign_in_with_password(conn, email)
      passkey = enrol_passkey(conn, strategy)

      # The verify page in token mode, mounted with an `auth_routes_prefix`,
      # which is where the missing route used to raise.
      {:ok, view, html} = live(conn, "/member/webauthn-verify/#{token}")
      refute html =~ "must be signed in"

      html = verify(view, strategy, passkey)
      refute html =~ "Verification failed"

      {action, params} = token_form(html)
      assert action == "/member-auth/member/webauthn/sign_in_with_token"
      assert %{"token" => "ey" <> _} = params

      conn = post(conn, action, params)

      assert html_response(conn, 200) =~ "Success"
      assert %DateTime{} = conn.assigns.current_user.__metadata__.webauthn_verified_at
      assert %{webauthn_verified_at: %DateTime{}} = get_session(conn, "member_metadata")
    end

    test "verifies the signed-in member in step-up mode, with no token in the URL",
         %{conn: conn, strategy: strategy, password: password} do
      {_member, email} = register_member!(password)
      {conn, _token} = sign_in_with_password(conn, email)
      passkey = enrol_passkey(conn, strategy)

      {:ok, view, html} = live(conn, "/member/webauthn-verify")
      refute html =~ "must be signed in"

      html = verify(view, strategy, passkey)

      {action, %{"token" => "ey" <> _}} = token_form(html)
      assert action == "/member-auth/member/webauthn/sign_in_with_token"
    end

    test "the pages refuse a visitor who is not signed in", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/member/webauthn-setup")
      assert html =~ "must be signed in to manage"

      {:ok, _view, html} = live(conn, "/member/webauthn-verify")
      assert html =~ "must be signed in to verify"
    end
  end
end
