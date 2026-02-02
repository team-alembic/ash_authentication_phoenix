# SPDX-FileCopyrightText: 2024 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Plug.RequireTotpTest do
  @moduledoc false

  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  alias AshAuthentication.Phoenix.Plug.RequireTotp

  describe "init/1" do
    test "requires resource option" do
      assert_raise KeyError, fn ->
        RequireTotp.init([])
      end
    end

    test "sets default options" do
      opts = RequireTotp.init(resource: Example.Accounts.User)
      assert opts.resource == Example.Accounts.User
      assert opts.on_missing == :halt
      assert opts.setup_path == "/auth/totp/setup"
      assert opts.current_user_assign == :current_user
      assert opts.error_message == "Two-factor authentication required"
    end

    test "allows custom options" do
      opts =
        RequireTotp.init(
          resource: Example.Accounts.User,
          strategy: :totp,
          on_missing: :redirect_to_setup,
          setup_path: "/custom/setup",
          current_user_assign: :user,
          error_message: "Custom message"
        )

      assert opts.strategy == :totp
      assert opts.on_missing == :redirect_to_setup
      assert opts.setup_path == "/custom/setup"
      assert opts.current_user_assign == :user
      assert opts.error_message == "Custom message"
    end
  end

  describe "call/2" do
    setup do
      user_without_totp =
        Example.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "plug-test-#{System.unique_integer()}@example.com",
          password: "password123!",
          password_confirmation: "password123!"
        })
        |> Ash.create!()

      {:ok, user_without_totp: user_without_totp}
    end

    test "passes through when no user is assigned" do
      opts = RequireTotp.init(resource: Example.Accounts.User)

      conn =
        conn(:get, "/")
        |> RequireTotp.call(opts)

      refute conn.halted
    end

    test "halts with 403 when user has no TOTP and on_missing is :halt", %{
      user_without_totp: user
    } do
      opts = RequireTotp.init(resource: Example.Accounts.User, on_missing: :halt)

      conn =
        conn(:get, "/")
        |> assign(:current_user, user)
        |> RequireTotp.call(opts)

      assert conn.halted
      assert conn.status == 403
      assert conn.resp_body == "Two-factor authentication required"
    end

    test "redirects when user has no TOTP and on_missing is :redirect_to_setup", %{
      user_without_totp: user
    } do
      opts =
        RequireTotp.init(
          resource: Example.Accounts.User,
          on_missing: :redirect_to_setup,
          setup_path: "/auth/totp/setup"
        )

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> fetch_flash()
        |> assign(:current_user, user)
        |> RequireTotp.call(opts)

      assert conn.halted
      assert get_resp_header(conn, "location") == ["/auth/totp/setup"]
    end

    test "redirects to custom path when on_missing is {:redirect, path}", %{
      user_without_totp: user
    } do
      opts =
        RequireTotp.init(
          resource: Example.Accounts.User,
          on_missing: {:redirect, "/custom/path"}
        )

      conn =
        conn(:get, "/")
        |> init_test_session(%{})
        |> fetch_flash()
        |> assign(:current_user, user)
        |> RequireTotp.call(opts)

      assert conn.halted
      assert get_resp_header(conn, "location") == ["/custom/path"]
    end

    test "respects custom current_user_assign", %{user_without_totp: user} do
      opts =
        RequireTotp.init(
          resource: Example.Accounts.User,
          current_user_assign: :actor,
          on_missing: :halt
        )

      # With default assign - should pass through (no user at :actor)
      conn1 =
        conn(:get, "/")
        |> assign(:current_user, user)
        |> RequireTotp.call(opts)

      refute conn1.halted

      # With custom assign - should halt
      conn2 =
        conn(:get, "/")
        |> assign(:actor, user)
        |> RequireTotp.call(opts)

      assert conn2.halted
    end
  end

  defp fetch_flash(conn) do
    conn
    |> fetch_session()
    |> Phoenix.Controller.fetch_flash([])
  end
end
