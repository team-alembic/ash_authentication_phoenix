# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy.Otp do
    use Igniter.Mix.Task

    @example "mix ash_authentication_phoenix.add_strategy otp"

    @shortdoc "Adds Phoenix integration for the OTP authentication strategy"

    @moduledoc """
    #{@shortdoc}

    Upgrades the OTP sender to deliver the code as a Swoosh email when a
    Swoosh mailer is available.

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    * `--user`, `-u` - The user resource. Defaults to `YourApp.Accounts.User`
    """

    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :ash,
        example: @example,
        extra_args?: false,
        only: nil,
        positional: [],
        schema: [
          accounts: :string,
          user: :string,
          identity_field: :string
        ],
        aliases: [
          a: :accounts,
          u: :user,
          i: :identity_field
        ],
        defaults: [
          identity_field: "email"
        ]
      }
    end

    def igniter(igniter) do
      options = parse_options(igniter)
      sender = Module.concat(options[:user], Senders.SendOtp)

      upgrade_sender(igniter, sender, options)
    end

    defp parse_options(igniter) do
      options =
        igniter.args.options
        |> Keyword.put_new_lazy(:accounts, fn ->
          Igniter.Project.Module.module_name(igniter, "Accounts")
        end)

      options
      |> Keyword.put_new_lazy(:user, fn ->
        Module.concat(options[:accounts], User)
      end)
      |> Keyword.update(:identity_field, :email, &String.to_atom/1)
      |> Keyword.update!(:accounts, &maybe_parse_module/1)
      |> Keyword.update!(:user, &maybe_parse_module/1)
    end

    defp maybe_parse_module(value) when is_binary(value), do: Igniter.Project.Module.parse(value)
    defp maybe_parse_module(value), do: value

    defp upgrade_sender(igniter, sender, _options) do
      case Igniter.Libs.Swoosh.list_mailers(igniter) do
        {igniter, [mailer]} ->
          contents =
            """
            defmodule #{inspect(sender)} do
              @moduledoc \"\"\"
              Sends a one-time password code to the user.
              \"\"\"

              use AshAuthentication.Sender

              import Swoosh.Email
              alias #{inspect(mailer)}

              @impl true
              def send(user, otp_code, _) do
                new()
                |> from({"noreply", "noreply@example.com"})
                |> to(to_string(user.email))
                |> subject("Your sign-in code")
                |> html_body(body([code: otp_code, email: user.email]))
                |> #{List.last(Module.split(mailer))}.deliver!()
              end

              defp body(params) do
                \"\"\"
                <p>Hello, \#{params[:email]}! Your sign-in code is:</p>
                <p style="font-size: 24px; font-weight: bold; letter-spacing: 4px;">\#{params[:code]}</p>
                <p>This code expires in 10 minutes.</p>
                \"\"\"
              end
            end
            """

          location =
            Igniter.Project.Module.proper_location(igniter, sender)

          Igniter.create_new_file(igniter, location, contents, on_exists: :overwrite)

        _ ->
          igniter
      end
    end
  end
else
  defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy.Otp do
    @shortdoc "Adds Phoenix integration for the OTP authentication strategy"

    @moduledoc @shortdoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_authentication_phoenix.add_strategy.otp' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
