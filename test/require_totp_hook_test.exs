# SPDX-FileCopyrightText: 2024 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.LiveSession.RequireTotpTest do
  @moduledoc false

  use ExUnit.Case, async: false
  alias AshAuthentication.Phoenix.LiveSession.RequireTotp
  alias AshAuthentication.Phoenix.TotpHelpers

  describe "on_mount/4 with :require_totp" do
    test "continues when no user is assigned" do
      socket = build_socket(%{current_user: nil})
      {:cont, result_socket} = RequireTotp.on_mount(:require_totp, %{}, %{}, socket)

      refute Map.has_key?(result_socket.assigns, :totp_configured)
    end

    test "halts with redirect when user has no TOTP configured" do
      user = create_user_without_totp()
      socket = build_socket(%{current_user: user})

      {:halt, result_socket} = RequireTotp.on_mount(:require_totp, %{}, %{}, socket)

      assert result_socket.assigns.totp_configured == false
      assert result_socket.redirected == {:redirect, %{status: 302, to: "/auth/totp/setup"}}
    end

    test "continues when user has TOTP configured" do
      user = create_user_with_totp()
      socket = build_socket(%{current_user: user})

      {:cont, result_socket} = RequireTotp.on_mount(:require_totp, %{}, %{}, socket)

      assert result_socket.assigns.totp_configured == true
    end
  end

  describe "on_mount/4 with options" do
    test "uses custom setup_path" do
      user = create_user_without_totp()
      socket = build_socket(%{current_user: user})

      {:halt, result_socket} =
        RequireTotp.on_mount(
          {:require_totp, setup_path: "/custom/setup"},
          %{},
          %{},
          socket
        )

      assert result_socket.redirected == {:redirect, %{status: 302, to: "/custom/setup"}}
    end

    test "uses custom current_user_assign" do
      user = create_user_without_totp()
      socket = build_socket(%{actor: user})

      {:halt, result_socket} =
        RequireTotp.on_mount(
          {:require_totp, current_user_assign: :actor},
          %{},
          %{},
          socket
        )

      assert result_socket.assigns.totp_configured == false
    end

    test "continues when custom assign has no user" do
      socket = build_socket(%{current_user: nil, actor: nil})

      {:cont, result_socket} =
        RequireTotp.on_mount(
          {:require_totp, current_user_assign: :actor},
          %{},
          %{},
          socket
        )

      refute Map.has_key?(result_socket.assigns, :totp_configured)
    end
  end

  describe "require_totp/2" do
    test "returns {:cont, socket} when no user" do
      socket = build_socket(%{current_user: nil})
      {:cont, result_socket} = RequireTotp.require_totp(socket)

      refute Map.has_key?(result_socket.assigns, :totp_configured)
    end

    test "returns {:halt, socket} with redirect when user lacks TOTP" do
      user = create_user_without_totp()
      socket = build_socket(%{current_user: user})

      {:halt, result_socket} = RequireTotp.require_totp(socket)

      assert result_socket.assigns.totp_configured == false
      assert result_socket.redirected == {:redirect, %{status: 302, to: "/auth/totp/setup"}}
    end

    test "returns {:cont, socket} when user has TOTP" do
      user = create_user_with_totp()
      socket = build_socket(%{current_user: user})

      {:cont, result_socket} = RequireTotp.require_totp(socket)

      assert result_socket.assigns.totp_configured == true
    end

    test "accepts custom options" do
      user = create_user_without_totp()
      socket = build_socket(%{current_user: user})

      {:halt, result_socket} =
        RequireTotp.require_totp(socket,
          setup_path: "/my/setup",
          error_message: "Custom error"
        )

      assert result_socket.redirected == {:redirect, %{status: 302, to: "/my/setup"}}
    end
  end

  describe "totp_configured?/2" do
    test "returns false when no user" do
      socket = build_socket(%{current_user: nil})
      refute RequireTotp.totp_configured?(socket)
    end

    test "returns false when user lacks TOTP" do
      user = create_user_without_totp()
      socket = build_socket(%{current_user: user})

      refute RequireTotp.totp_configured?(socket)
    end

    test "returns true when user has TOTP" do
      user = create_user_with_totp()
      socket = build_socket(%{current_user: user})

      assert RequireTotp.totp_configured?(socket)
    end

    test "respects custom current_user_assign" do
      user = create_user_without_totp()
      socket = build_socket(%{actor: user})

      refute RequireTotp.totp_configured?(socket, current_user_assign: :actor)
    end
  end

  defp build_socket(assigns) do
    base_assigns = %{
      __changed__: %{},
      flash: %{}
    }

    %Phoenix.LiveView.Socket{
      endpoint: AshAuthentication.Phoenix.Test.Endpoint,
      assigns: Map.merge(base_assigns, assigns)
    }
  end

  defp create_user_without_totp do
    Example.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: "hook-no-totp-#{System.unique_integer()}@example.com",
      password: "password123!",
      password_confirmation: "password123!"
    })
    |> Ash.create!()
  end

  defp create_user_with_totp do
    user = create_user_without_totp()

    {:ok, strategy} = TotpHelpers.get_totp_strategy(Example.Accounts.User)

    {:ok, user_with_pending_setup} =
      AshAuthentication.Strategy.action(strategy, :setup, %{user: user}, [])

    setup_token = Ash.Resource.get_metadata(user_with_pending_setup, :setup_token)
    totp_url = Ash.Resource.get_metadata(user_with_pending_setup, :totp_url)

    %URI{query: query} = URI.parse(totp_url)
    %{"secret" => encoded_secret} = URI.decode_query(query)
    secret = Base.decode32!(encoded_secret, padding: false)

    code = NimbleTOTP.verification_code(secret)

    {:ok, confirmed_user} =
      AshAuthentication.Strategy.action(
        strategy,
        :confirm_setup,
        %{user: user_with_pending_setup, setup_token: setup_token, code: code},
        []
      )

    confirmed_user
  end
end
