# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy.OtpTest do
  use ExUnit.Case

  import Igniter.Test

  @moduletag :igniter

  defp setup_with_otp do
    test_project()
    |> Igniter.Project.Deps.add_dep({:simple_sat, ">= 0.0.0"})
    |> Igniter.Project.Deps.add_dep({:ash_authentication, ">= 0.0.0"})
    |> Igniter.Project.Formatter.add_formatter_plugin(Spark.Formatter)
    |> Igniter.compose_task("ash_authentication.install", ["--yes"])
    |> Igniter.compose_task("ash_authentication.add_strategy", ["otp"])
    |> apply_igniter!()
  end

  defp setup_with_otp_and_mailer do
    setup_with_otp()
    |> Igniter.Project.Module.create_module(Test.Mailer, """
    use Swoosh.Mailer, otp_app: :test
    """)
    |> apply_igniter!()
  end

  describe "without Swoosh" do
    test "leaves the SendOtp module untouched" do
      igniter = setup_with_otp()

      igniter
      |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.otp", [])
      |> assert_unchanged("lib/test/accounts/user/senders/send_otp.ex")
    end

    test "does not configure the development mailbox path" do
      result =
        setup_with_otp()
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.otp", [])

      refute diff(result) =~ "dev_mailbox_path"
    end
  end

  describe "with Swoosh" do
    test "upgrades SendOtp to use Swoosh" do
      result =
        setup_with_otp_and_mailer()
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.otp", [])

      diff = diff(result, path: "lib/test/accounts/user/senders/send_otp.ex")
      assert diff =~ "import Swoosh.Email"
      assert diff =~ "Test.Mailer"
      assert diff =~ "Mailer.deliver!()"
      assert diff =~ "subject(\"Your sign-in code\")"
    end

    test "uses the user's email address in the To field" do
      result =
        setup_with_otp_and_mailer()
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.otp", [])

      diff = diff(result, path: "lib/test/accounts/user/senders/send_otp.ex")
      assert diff =~ "to(to_string(user.email))"
    end

    test "configures the development mailbox path" do
      result =
        setup_with_otp_and_mailer()
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy.otp", [])

      assert diff(result, path: "config/dev.exs") =~
               ~s{config :ash_authentication, dev_mailbox_path: "/dev/mailbox"}
    end

    test "leaves an existing development mailbox path alone" do
      igniter =
        setup_with_otp_and_mailer()
        |> Igniter.Project.Config.configure_new(
          "dev.exs",
          :ash_authentication,
          [:dev_mailbox_path],
          "/inbox"
        )
        |> apply_igniter!()

      result =
        Igniter.compose_task(igniter, "ash_authentication_phoenix.add_strategy.otp", [])

      assert_unchanged(result, "config/dev.exs")
    end
  end

  describe "via parent task" do
    test "ash_authentication_phoenix.add_strategy otp composes both AA and Phoenix tasks" do
      igniter =
        test_project()
        |> Igniter.Project.Deps.add_dep({:simple_sat, ">= 0.0.0"})
        |> Igniter.Project.Deps.add_dep({:ash_authentication, ">= 0.0.0"})
        |> Igniter.Project.Formatter.add_formatter_plugin(Spark.Formatter)
        |> Igniter.compose_task("ash_authentication.install", ["--yes"])
        |> apply_igniter!()

      result =
        igniter
        |> Igniter.compose_task("ash_authentication_phoenix.add_strategy", ["otp"])

      assert_creates(result, "lib/test/accounts/user/senders/send_otp.ex")

      # OTP strategy was added to the user resource
      assert_has_patch(result, "lib/test/accounts/user.ex", """
      + |    otp :otp do
      + |      identity_field :email
      + |      brute_force_strategy {:audit_log, :audit_log}
      + |      sender Test.Accounts.User.Senders.SendOtp
      + |    end
      """)
    end
  end
end
