# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.WebAuthnVerifyDisabledTest do
  @moduledoc false

  use AshAuthentication.Phoenix.Test.ConnCase, async: false

  alias AshAuthentication.Info
  alias AshAuthentication.Phoenix.Test.WebAuthnFixtures, as: Fixtures

  @moduletag :webauthn_strategy_required

  setup do
    {:ok, strategy: Info.strategy!(Example.Accounts.User, :webauthn)}
  end

  defp register_user!(strategy) do
    email = "no-verify-#{System.unique_integer([:positive])}@example.com"

    {{:ok, user}, _passkey} =
      Fixtures.register(strategy, %{"email" => email, "name" => "Someone"})

    user
  end

  defp signed_in(conn, user) do
    init_test_session(conn, %{"user" => "test-jti:" <> AshAuthentication.user_to_subject(user)})
  end

  describe "Verify2faForm with verify_enabled? false" do
    test "renders the notice instead of the form", %{conn: conn, strategy: strategy} do
      user = register_user!(strategy)

      {:ok, _view, html} = conn |> signed_in(user) |> live("/webauthn-verify-variant/no-verify")

      assert html =~ "Passkey verification is not enabled."
      refute html =~ "verify-form"
      refute html =~ "Verify with passkey</button>"
    end

    test "refuses a start-verify event without starting a ceremony",
         %{conn: conn, strategy: strategy} do
      user = register_user!(strategy)

      {:ok, view, _html} = conn |> signed_in(user) |> live("/webauthn-verify-variant/no-verify")

      html = view |> element("#verify") |> render_hook("start-verify", %{})

      assert html =~ "Passkey verification is not enabled."
      refute_push_event(view, "authentication-challenge", %{})
    end
  end
end
