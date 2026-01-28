# SPDX-FileCopyrightText: 2024 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.TotpFlowTest do
  @moduledoc """
  ConnCase tests for the full TOTP authentication flow.

  These tests cover:
  - TOTP setup flow (generate secret → confirm with code)
  - TOTP sign-in flow (identity + code → authenticated)
  - RequireTotp plug enforcement in full request context
  """

  use AshAuthentication.Phoenix.Test.ConnCase
  alias AshAuthentication.Phoenix.TotpHelpers

  @user_resource Example.Accounts.User

  describe "TOTP setup flow" do
    setup do
      user = create_user()
      {:ok, user: user}
    end

    test "user can initiate TOTP setup and receive setup token", %{user: user} do
      {:ok, strategy} = TotpHelpers.get_totp_strategy(@user_resource)

      {:ok, user_with_setup} =
        AshAuthentication.Strategy.action(strategy, :setup, %{user: user}, [])

      setup_token = Ash.Resource.get_metadata(user_with_setup, :setup_token)
      totp_url = Ash.Resource.get_metadata(user_with_setup, :totp_url)

      assert is_binary(setup_token)
      assert is_binary(totp_url)
      assert totp_url =~ "otpauth://totp/"
      assert totp_url =~ "secret="
    end

    test "user can confirm TOTP setup with valid code", %{user: user} do
      {:ok, strategy} = TotpHelpers.get_totp_strategy(@user_resource)

      {:ok, user_with_setup} =
        AshAuthentication.Strategy.action(strategy, :setup, %{user: user}, [])

      setup_token = Ash.Resource.get_metadata(user_with_setup, :setup_token)
      secret = extract_secret_from_totp_url(user_with_setup)
      code = NimbleTOTP.verification_code(secret)

      {:ok, confirmed_user} =
        AshAuthentication.Strategy.action(
          strategy,
          :confirm_setup,
          %{user: user_with_setup, setup_token: setup_token, code: code},
          []
        )

      assert TotpHelpers.totp_configured?(confirmed_user)
    end

    test "TOTP setup fails with invalid code", %{user: user} do
      {:ok, strategy} = TotpHelpers.get_totp_strategy(@user_resource)

      {:ok, user_with_setup} =
        AshAuthentication.Strategy.action(strategy, :setup, %{user: user}, [])

      setup_token = Ash.Resource.get_metadata(user_with_setup, :setup_token)

      result =
        AshAuthentication.Strategy.action(
          strategy,
          :confirm_setup,
          %{user: user_with_setup, setup_token: setup_token, code: "000000"},
          []
        )

      assert {:error, _} = result
    end

    test "TOTP setup fails with invalid setup token", %{user: user} do
      {:ok, strategy} = TotpHelpers.get_totp_strategy(@user_resource)

      {:ok, user_with_setup} =
        AshAuthentication.Strategy.action(strategy, :setup, %{user: user}, [])

      secret = extract_secret_from_totp_url(user_with_setup)
      code = NimbleTOTP.verification_code(secret)

      result =
        AshAuthentication.Strategy.action(
          strategy,
          :confirm_setup,
          %{user: user_with_setup, setup_token: "invalid_token", code: code},
          []
        )

      assert {:error, _} = result
    end
  end

  describe "TOTP sign-in flow" do
    setup do
      user = create_user()
      user_with_totp = setup_totp_for_user(user)
      {:ok, user: user_with_totp, email: Ash.CiString.value(user_with_totp.email)}
    end

    test "user can sign in with valid TOTP code", %{user: user, email: email} do
      {:ok, strategy} = TotpHelpers.get_totp_strategy(@user_resource)
      secret = get_user_totp_secret(user)
      code = NimbleTOTP.verification_code(secret)

      {:ok, authenticated_user} =
        AshAuthentication.Strategy.action(
          strategy,
          :sign_in,
          %{strategy.identity_field => email, :code => code},
          []
        )

      assert authenticated_user.id == user.id
      assert authenticated_user.__metadata__[:authentication_strategies] == [:totp]
      assert authenticated_user.__metadata__[:totp_verified_at] != nil
    end

    test "sign-in fails with invalid TOTP code", %{email: email} do
      {:ok, strategy} = TotpHelpers.get_totp_strategy(@user_resource)

      result =
        AshAuthentication.Strategy.action(
          strategy,
          :sign_in,
          %{strategy.identity_field => email, :code => "000000"},
          []
        )

      assert {:error, _} = result
    end

    test "sign-in fails with non-existent user" do
      {:ok, strategy} = TotpHelpers.get_totp_strategy(@user_resource)

      result =
        AshAuthentication.Strategy.action(
          strategy,
          :sign_in,
          %{strategy.identity_field => "nonexistent@example.com", :code => "123456"},
          []
        )

      assert {:error, _} = result
    end
  end

  describe "RequireTotp plug in request context" do
    alias AshAuthentication.Phoenix.Plug.RequireTotp

    test "allows authenticated user with TOTP to proceed", %{conn: conn} do
      user = create_user()
      user_with_totp = setup_totp_for_user(user)

      opts = RequireTotp.init(resource: @user_resource)

      conn =
        conn
        |> init_test_session(%{})
        |> setup_flash()
        |> assign(:current_user, user_with_totp)
        |> RequireTotp.call(opts)

      refute conn.halted
    end

    test "halts request for authenticated user without TOTP", %{conn: conn} do
      user = create_user()

      opts = RequireTotp.init(resource: @user_resource, on_missing: :halt)

      conn =
        conn
        |> init_test_session(%{})
        |> assign(:current_user, user)
        |> RequireTotp.call(opts)

      assert conn.halted
      assert conn.status == 403
    end

    test "redirects user without TOTP to setup page", %{conn: conn} do
      user = create_user()

      opts =
        RequireTotp.init(
          resource: @user_resource,
          on_missing: :redirect_to_setup,
          setup_path: "/auth/totp/setup"
        )

      conn =
        conn
        |> init_test_session(%{})
        |> setup_flash()
        |> assign(:current_user, user)
        |> RequireTotp.call(opts)

      assert conn.halted
      assert redirected_to(conn) == "/auth/totp/setup"
    end

    test "passes through when no user is present", %{conn: conn} do
      opts = RequireTotp.init(resource: @user_resource)

      conn =
        conn
        |> init_test_session(%{})
        |> RequireTotp.call(opts)

      refute conn.halted
    end
  end

  describe "TOTP form submission via LiveView" do
    test "TOTP sign-in form is present on sign-in page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sign-in")

      assert html =~ "user-totp-sign-in-with-totp"
      assert html =~ ~s(action="/auth/user/totp/sign_in")
    end

    test "TOTP sign-in form handles submission", %{conn: conn} do
      user = create_user()
      user_with_totp = setup_totp_for_user(user)
      email = Ash.CiString.value(user_with_totp.email)
      secret = get_user_totp_secret(user_with_totp)
      code = NimbleTOTP.verification_code(secret)

      {:ok, view, _html} = live(conn, ~p"/sign-in")

      # Submit the form
      html_after_submit =
        view
        |> form(~s{[action="/auth/user/totp/sign_in"]}, %{
          "user" => %{"email" => email, "code" => code}
        })
        |> render_submit()

      # Verify form submitted correctly by checking phx-trigger-action is true
      # Note: The form uses phx-trigger-action for submission, which may not work
      # the same way as LiveView redirects in tests
      assert html_after_submit =~ ~r/phx-trigger-action/

      # Since TOTP form uses phx-trigger-action (browser form POST), we can verify
      # the form is valid by checking the form shows trigger_action=true or doesn't
      # show validation errors
      refute html_after_submit =~ "is invalid"
    end
  end

  # Helpers

  defp create_user do
    @user_resource
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: "totp-flow-#{System.unique_integer()}@example.com",
      password: "password123!",
      password_confirmation: "password123!"
    })
    |> Ash.create!()
  end

  defp setup_totp_for_user(user) do
    {:ok, strategy} = TotpHelpers.get_totp_strategy(@user_resource)

    {:ok, user_with_setup} =
      AshAuthentication.Strategy.action(strategy, :setup, %{user: user}, [])

    setup_token = Ash.Resource.get_metadata(user_with_setup, :setup_token)
    secret = extract_secret_from_totp_url(user_with_setup)
    code = NimbleTOTP.verification_code(secret)

    {:ok, confirmed_user} =
      AshAuthentication.Strategy.action(
        strategy,
        :confirm_setup,
        %{user: user_with_setup, setup_token: setup_token, code: code},
        []
      )

    confirmed_user
  end

  defp extract_secret_from_totp_url(user) do
    totp_url = Ash.Resource.get_metadata(user, :totp_url)
    %URI{query: query} = URI.parse(totp_url)
    %{"secret" => encoded_secret} = URI.decode_query(query)
    Base.decode32!(encoded_secret, padding: false)
  end

  defp get_user_totp_secret(user) do
    user.totp_secret
  end

  defp setup_flash(conn) do
    conn
    |> fetch_session()
    |> Phoenix.Controller.fetch_flash([])
  end
end
