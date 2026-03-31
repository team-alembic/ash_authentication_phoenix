# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy.MagicLink do
    use Igniter.Mix.Task

    @example "mix ash_authentication_phoenix.add_strategy magic_link"

    @shortdoc "Adds Phoenix integration for the magic link authentication strategy"

    @moduledoc """
    #{@shortdoc}

    Upgrades the magic link sender to use Swoosh and Phoenix verified routes
    when available.

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
      sender = Module.concat(options[:user], Senders.SendMagicLinkEmail)

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
          web_module = Igniter.Libs.Phoenix.web_module(igniter)

          contents =
            """
            defmodule #{inspect(sender)} do
              @moduledoc \"\"\"
              Sends a magic link email
              \"\"\"

              use AshAuthentication.Sender
              use #{inspect(web_module)}, :verified_routes

              import Swoosh.Email
              alias #{inspect(mailer)}

              @impl true
              def send(user_or_email, token, _) do
                email =
                  case user_or_email do
                    %{email: email} -> email
                    email -> email
                  end

                new()
                |> from({"noreply", "noreply@example.com"})
                |> to(to_string(email))
                |> subject("Your login link")
                |> html_body(body([token: token, email: email]))
                |> #{List.last(Module.split(mailer))}.deliver!()
              end

              defp body(params) do
                url = url(~p"/magic_link/\#{params[:token]}")

                \"\"\"
                <p>Hello, \#{params[:email]}! Click this link to sign in:</p>
                <p><a href="\#{url}">\#{url}</a></p>
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
  defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy.MagicLink do
    @shortdoc "Adds Phoenix integration for the magic link authentication strategy"

    @moduledoc @shortdoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_authentication_phoenix.add_strategy.magic_link' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
