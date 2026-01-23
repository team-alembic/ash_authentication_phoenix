# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.MagicSignInTest do
  @moduledoc false

  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias AshAuthentication.{Info, Strategy}

  @endpoint AshAuthentication.Phoenix.Test.Endpoint

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  describe "when require_interaction? is true" do
    test "form displays and requires user interaction to submit", %{conn: conn} do
      user =
        Example.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "magic@example.com",
          password: "so-secure!",
          password_confirmation: "so-secure!"
        })
        |> Ash.create!()

      strategy = Info.strategy!(Example.Accounts.User, :magic_link)
      {:ok, token} = Strategy.MagicLink.request_token_for(strategy, user)

      conn = get(conn, "/magic_link/#{token}")
      assert {:ok, view, html} = live(conn)

      assert html =~ "Sign in"
      refute has_element?(view, "form[phx-trigger-action]")
    end
  end

  describe "when require_interaction? is false" do
    test "form auto-submits on mount", %{conn: conn} do
      user =
        Example.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "magic-auto@example.com",
          password: "so-secure!",
          password_confirmation: "so-secure!"
        })
        |> Ash.create!()

      strategy = Info.strategy!(Example.Accounts.User, :no_interaction)
      {:ok, token} = Strategy.MagicLink.request_token_for(strategy, user)

      conn = get(conn, "/magic-no-interaction/#{token}")
      assert {:ok, view, _html} = live(conn)

      assert has_element?(view, "form[phx-trigger-action]")
    end
  end
end
