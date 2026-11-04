# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.WebAuthnManageCredentialsTest do
  @moduledoc false

  use AshAuthentication.Phoenix.Test.ConnCase, async: false

  alias AshAuthentication.Info
  alias AshAuthentication.Phoenix.Test.WebAuthnFixtures, as: Fixtures
  alias AshAuthentication.Strategy.WebAuthn

  @moduletag :webauthn_strategy_required

  setup do
    {:ok, strategy: Info.strategy!(Example.Accounts.User, :webauthn)}
  end

  defp register_user!(strategy) do
    email = "manage-#{System.unique_integer([:positive])}@example.com"

    {{:ok, user}, passkey} =
      Fixtures.register(strategy, %{"email" => email, "name" => "Someone"})

    {user, passkey}
  end

  # The session `load_from_session` and `LiveSession` read, as
  # `AshAuthentication.Plug.Helpers.store_in_session/2` writes it: the
  # subject under the subject name and, when asked for, the authentication
  # metadata (here the sign-in token, whose `iat` dates the sign-in).
  defp signed_in(conn, user, opts \\ []) do
    session = %{"user" => "test-jti:" <> AshAuthentication.user_to_subject(user)}

    session =
      if Keyword.get(opts, :with_token, true),
        do: Map.put(session, "user_metadata", %{token: user.__metadata__.token}),
        else: session

    init_test_session(conn, session)
  end

  # `id` is the component id: `webauthn_setup` on the setup page, `manage`
  # in the variant LiveView.
  defp start_add(view, id) do
    view |> form("##{id}-add-key-form", %{"key_name" => "My new key"}) |> render_submit()
  end

  defp complete_add(view, id, strategy, challenge) do
    {event, _passkey} = Fixtures.attestation_event(strategy, challenge)
    view |> element("##{id}-add-key") |> render_hook("registration-attestation", event)
  end

  defp credentials_of(strategy, user) do
    {:ok, credentials} = WebAuthn.Actions.list_credentials(strategy, user, [])
    credentials
  end

  describe "listing and editing" do
    test "lists the user's credentials and offers to add another",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, _view, html} = conn |> signed_in(user) |> live("/webauthn-setup")

      assert html =~ "Security Key"
      assert html =~ "Rename"
      assert html =~ "Add another security key"
    end

    test "renames a credential by its primary key", %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, _html} = conn |> signed_in(user) |> live("/webauthn-setup")

      view |> element("button", "Rename") |> render_click()
      [credential] = credentials_of(strategy, user)

      html =
        view
        |> form("#credential-#{credential.id}-form", %{"label" => "Work laptop"})
        |> render_submit()

      assert html =~ "Work laptop"
      refute html =~ "Credential not found"
    end

    test "refuses to delete the last credential", %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, _html} = conn |> signed_in(user) |> live("/webauthn-setup")

      html = view |> element("button", "Delete") |> render_click()

      assert html =~ "Cannot delete your last security key"
      assert html =~ "Rename"
    end
  end

  describe "adding a passkey" do
    test "issues creation options excluding the credentials already registered",
         %{conn: conn, strategy: strategy} do
      {user, passkey} = register_user!(strategy)

      {:ok, view, _html} = conn |> signed_in(user) |> live("/webauthn-setup")
      start_add(view, "webauthn_setup")

      assert_push_event(view, "registration-challenge", %{
        excludeCredentials: [%{id: excluded_id, type: "public-key"}],
        user: %{id: user_handle, name: name}
      })

      assert excluded_id == passkey.raw_id
      # The existing passkey's handle is reused so every passkey of the
      # account presents the same identity.
      assert Base.url_decode64!(user_handle, padding: false) == passkey.user_handle
      assert name == to_string(user.email)
    end

    test "stores the new credential and lists it", %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, _html} = conn |> signed_in(user) |> live("/webauthn-setup")
      start_add(view, "webauthn_setup")
      assert_push_event(view, "registration-challenge", %{challenge: challenge})

      html = complete_add(view, "webauthn_setup", strategy, challenge)

      assert html =~ "My new key"
      refute html =~ "Failed to register"
      assert [_, _] = credentials_of(strategy, user)
    end
  end

  describe "with add_credential_enabled? false" do
    test "the add affordance is not rendered", %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, _view, html} = conn |> signed_in(user) |> live("/webauthn-manage/disabled")

      assert html =~ "Rename"
      refute html =~ "Add another security key"
      refute html =~ "manage-add-key"
    end

    test "an add-credential event sent anyway is refused as disabled, with no redirect",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, _html} = conn |> signed_in(user) |> live("/webauthn-manage/disabled")

      # The form isn't rendered, so this is a hand-made event to the component.
      html = view |> with_target("#manage") |> render_hook("add-credential", %{})

      assert html =~ "Adding a passkey is not enabled."
      refute_push_event(view, "registration-challenge", %{})
    end
  end

  describe "with add_credential_max_authentication_age" do
    test "a session whose token was issued within the window may add a passkey",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, _html} = conn |> signed_in(user) |> live("/webauthn-manage/recent")
      start_add(view, "manage")

      assert_push_event(view, "registration-challenge", %{challenge: _})
    end

    test "a session with no datable authentication is sent to verify first",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, _html} =
        conn |> signed_in(user, with_token: false) |> live("/webauthn-manage/recent")

      start_add(view, "manage")

      # The user already holds a passkey and the strategy verifies, so the
      # second-factor page is the lighter proof.
      assert_redirect(view, "/webauthn-verify")
      refute_push_event(view, "registration-challenge", %{})
    end

    test "without a verify phase the user is sent to sign in again",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, _html} =
        conn |> signed_in(user, with_token: false) |> live("/webauthn-manage/recent-no-verify")

      start_add(view, "manage")

      assert_redirect(view, "/sign-in")
    end

    test "an authentication time the application knows is honoured",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)
      just_now = DateTime.utc_now() |> DateTime.to_iso8601()

      {:ok, view, _html} =
        conn
        |> signed_in(user, with_token: false)
        |> live("/webauthn-manage/recent?authenticated_at=#{URI.encode_www_form(just_now)}")

      start_add(view, "manage")

      assert_push_event(view, "registration-challenge", %{challenge: _})
    end

    test "an authentication time outside the window is refused",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      stale =
        DateTime.utc_now() |> DateTime.add(-10, :minute) |> DateTime.to_iso8601()

      {:ok, view, _html} =
        conn
        |> signed_in(user, with_token: false)
        |> live("/webauthn-manage/recent?authenticated_at=#{URI.encode_www_form(stale)}")

      start_add(view, "manage")

      assert_redirect(view, "/webauthn-verify")
    end

    test "a window that lapses mid-ceremony is refused when the credential is stored",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      # One second of allowed age, authenticated one second ago: the check
      # before the ceremony passes, the one at storage, a moment later,
      # does not.
      authenticated_at =
        DateTime.utc_now() |> DateTime.add(-1, :second) |> DateTime.to_iso8601()

      {:ok, view, _html} =
        conn
        |> signed_in(user, with_token: false)
        |> live(
          "/webauthn-manage/recent-second?authenticated_at=#{URI.encode_www_form(authenticated_at)}"
        )

      start_add(view, "manage")
      assert_push_event(view, "registration-challenge", %{challenge: challenge})

      Process.sleep(1_100)

      complete_add(view, "manage", strategy, challenge)

      assert_redirect(view, "/webauthn-verify")
      assert [_only_the_original] = credentials_of(strategy, user)
    end
  end
end
