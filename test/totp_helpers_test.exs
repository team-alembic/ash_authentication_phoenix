# SPDX-FileCopyrightText: 2024 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.TotpHelpersTest do
  @moduledoc false

  use ExUnit.Case, async: false
  alias AshAuthentication.Phoenix.TotpHelpers

  describe "get_totp_strategy/2" do
    test "returns TOTP strategy for user resource" do
      assert {:ok, strategy} = TotpHelpers.get_totp_strategy(Example.Accounts.User)
      assert strategy.name == :totp
      assert strategy.identity_field == :email
    end

    test "returns error for resource without TOTP" do
      assert {:error, :no_totp_strategy} = TotpHelpers.get_totp_strategy(Example.Accounts.Token)
    end

    test "returns specific strategy by name" do
      assert {:ok, strategy} =
               TotpHelpers.get_totp_strategy(Example.Accounts.User, strategy: :totp)

      assert strategy.name == :totp
    end

    test "returns error for non-existent strategy name" do
      assert {:error, :no_totp_strategy} =
               TotpHelpers.get_totp_strategy(Example.Accounts.User, strategy: :nonexistent)
    end
  end

  describe "totp_available?/1" do
    test "returns true for resource with TOTP" do
      assert TotpHelpers.totp_available?(Example.Accounts.User)
    end

    test "returns false for resource without TOTP" do
      refute TotpHelpers.totp_available?(Example.Accounts.Token)
    end
  end

  describe "totp_secret_field/2" do
    test "returns secret field for TOTP strategy" do
      assert {:ok, :totp_secret} = TotpHelpers.totp_secret_field(Example.Accounts.User)
    end

    test "returns error for resource without TOTP" do
      assert {:error, :no_totp_strategy} = TotpHelpers.totp_secret_field(Example.Accounts.Token)
    end
  end

  describe "totp_configured?/2" do
    test "returns false for user without TOTP secret" do
      user =
        Example.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "no-totp-#{System.unique_integer()}@example.com",
          password: "password123!",
          password_confirmation: "password123!"
        })
        |> Ash.create!()

      refute TotpHelpers.totp_configured?(user)
    end

    test "returns true for user with TOTP secret" do
      user =
        Example.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "with-totp-#{System.unique_integer()}@example.com",
          password: "password123!",
          password_confirmation: "password123!"
        })
        |> Ash.create!()

      # Set up TOTP for the user
      {:ok, user_with_totp} =
        AshAuthentication.Strategy.action(
          get_totp_strategy(),
          :setup,
          %{user: user},
          []
        )

      # Get the setup token and extract secret from totp_url
      setup_token = Ash.Resource.get_metadata(user_with_totp, :setup_token)
      totp_url = Ash.Resource.get_metadata(user_with_totp, :totp_url)

      # Extract secret from TOTP URL
      %URI{query: query} = URI.parse(totp_url)
      %{"secret" => encoded_secret} = URI.decode_query(query)
      secret = Base.decode32!(encoded_secret, padding: false)

      # Generate a valid TOTP code
      code = NimbleTOTP.verification_code(secret)

      {:ok, confirmed_user} =
        AshAuthentication.Strategy.action(
          get_totp_strategy(),
          :confirm_setup,
          %{user: user_with_totp, setup_token: setup_token, code: code},
          []
        )

      assert TotpHelpers.totp_configured?(confirmed_user)
    end
  end

  defp get_totp_strategy do
    {:ok, strategy} = TotpHelpers.get_totp_strategy(Example.Accounts.User)
    strategy
  end
end
