# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.WebAuthnManageCredentialsTest do
  @moduledoc false

  use AshAuthentication.Phoenix.Test.ConnCase, async: false

  alias AshAuthentication.{Info, Strategy}
  alias AshAuthentication.Phoenix.Components.WebAuthn.ManageCredentials
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

  # Signs in with `passkey` through the strategy, which stamps the
  # credential's last-used time.
  defp sign_in_with!(strategy, passkey) do
    {:ok, challenge} = WebAuthn.Actions.authentication_challenge(strategy, [], nil)
    encoded = Base.url_encode64(strategy.adapter.challenge_bytes(challenge), padding: false)
    event = Fixtures.assertion_event(strategy, passkey, encoded)
    {:ok, _user} = WebAuthn.Actions.sign_in(strategy, event, challenge: challenge)
    :ok
  end

  defp timestamps_of(strategy, user) do
    [credential] = credentials_of(strategy, user)

    {Map.get(credential, WebAuthn.created_at_field(strategy)),
     Map.get(credential, WebAuthn.last_used_at_field(strategy))}
  end

  describe "text and dates" do
    test "a fresh, unnamed credential shows the fallback label and when it was added",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)
      {added, nil} = timestamps_of(strategy, user)

      {:ok, _view, html} = conn |> signed_in(user) |> live("/webauthn-manage/plain")

      assert html =~ "Added: #{ManageCredentials.format_timestamp(added, :added)}"
      # The test credential resource gives the label no default, so the
      # strategy stores none and the panel's own fallback shows.
      assert html =~ ~r/<strong class="font-semibold">\s*Security Key/
      refute html =~ "Last used"
      refute html =~ ~r/Added: [^<]*\|/
    end

    test "a credential renamed to nothing shows the fallback label",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, _html} = conn |> signed_in(user) |> live("/webauthn-manage/plain")
      view |> element("button", "Rename") |> render_click()
      [credential] = credentials_of(strategy, user)

      html =
        view
        |> form("#credential-#{credential.id}-form", %{"label" => ""})
        |> render_submit()

      assert html =~ ~r/<strong class="font-semibold">\s*Security Key/
    end

    test "a used credential shows both timestamps with the separator between",
         %{conn: conn, strategy: strategy} do
      {user, passkey} = register_user!(strategy)
      sign_in_with!(strategy, passkey)
      {added, last_used} = timestamps_of(strategy, user)

      {:ok, _view, html} = conn |> signed_in(user) |> live("/webauthn-manage/plain")

      assert html =~ "Added: #{ManageCredentials.format_timestamp(added, :added)}"
      assert html =~ ~r/Added: .*\|\s*Last used: /s
      assert html =~ "Last used: #{ManageCredentials.format_timestamp(last_used, :last_used)}"
    end

    test "the texts, the fallback label and the formatter are overrides",
         %{conn: conn, strategy: strategy} do
      {user, passkey} = register_user!(strategy)
      sign_in_with!(strategy, passkey)
      {added, last_used} = timestamps_of(strategy, user)

      {:ok, _view, html} =
        conn |> signed_in(user) |> live("/webauthn-manage/plain?overrides=panel")

      assert html =~ "Registrerad: added@#{DateTime.to_iso8601(added)}"
      assert html =~ "Senast använd: last_used@#{DateTime.to_iso8601(last_used)}"
      assert html =~ ~r/Registrerad: .*·\s*Senast använd: /s
      assert html =~ ~r/<strong class="panel-label">\s*Nyckel/
      refute html =~ ~r/<strong[^>]*>\s*Security Key/
      refute html =~ "Added:"
    end

    test "the fallback label is translated through gettext_fn",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, _view, html} = conn |> signed_in(user) |> live("/webauthn-manage/plain?gettext=stub")

      assert html =~ ~r/<strong class="font-semibold">\s*Never gonna give you up!/
      refute html =~ "Security Key"
    end
  end

  describe "styling" do
    test "every part of a row, the rename form and the error carry their class",
         %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, html} =
        conn |> signed_in(user) |> live("/webauthn-manage/plain?overrides=panel")

      assert html =~ ~s(<div class="panel-details">)
      assert html =~ ~s(<strong class="panel-label">)
      assert html =~ ~s(<div class="panel-actions">)

      html = view |> element("button", "Rename") |> render_click()
      assert html =~ ~s(class="panel-rename-form")
      assert html =~ ~s(<button type="submit" class="panel-save">)
      assert html =~ ~s(class="panel-cancel")

      view |> element("button", "Cancel") |> render_click()
      html = view |> element("button", "Delete") |> render_click()
      assert html =~ ~s(<div role="alert" class="panel-error">)
      assert html =~ "Cannot delete your last security key"
    end

    test "the empty state carries its class", %{conn: conn} do
      # A user with a password and no passkey yet.
      password = Info.strategy!(Example.Accounts.User, :password)
      email = "no-passkey-#{System.unique_integer([:positive])}@example.com"

      {:ok, user} =
        Strategy.action(
          password,
          :register,
          %{
            "email" => email,
            "password" => "so-secure!",
            "password_confirmation" => "so-secure!"
          },
          []
        )

      {:ok, _view, html} =
        conn |> signed_in(user) |> live("/webauthn-manage/plain?overrides=panel")

      assert html =~ ~s(<p class="panel-empty">)
      assert html =~ "No security keys registered."
    end

    test "the defaults style the error as before, with a role", %{conn: conn, strategy: strategy} do
      {user, _passkey} = register_user!(strategy)

      {:ok, view, _html} = conn |> signed_in(user) |> live("/webauthn-manage/plain")
      html = view |> element("button", "Delete") |> render_click()

      assert html =~ ~s(<div role="alert" class="text-red-600 text-sm mb-4">)
    end
  end
end
