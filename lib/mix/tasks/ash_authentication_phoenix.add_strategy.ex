# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy do
    use Igniter.Mix.Task

    @example "mix ash_authentication_phoenix.add_strategy password"

    @shortdoc "Adds a strategy to your user resource with Phoenix integration"

    @aa_strategy_tasks %{
      "password" => "ash_authentication.add_strategy.password",
      "magic_link" => "ash_authentication.add_strategy.magic_link",
      "api_key" => "ash_authentication.add_strategy.api_key",
      "totp" => "ash_authentication.add_strategy.totp",
      "recovery_code" => "ash_authentication.add_strategy.recovery_code"
    }

    @aap_strategy_tasks %{
      "password" => "ash_authentication_phoenix.add_strategy.password",
      "magic_link" => "ash_authentication_phoenix.add_strategy.magic_link",
      "totp" => "ash_authentication_phoenix.add_strategy.totp",
      "recovery_code" => "ash_authentication_phoenix.add_strategy.recovery_code"
    }

    @strategy_names Map.keys(@aa_strategy_tasks)

    @strategy_explanation [
                            password:
                              "Register and sign in with a username/email and a password.",
                            magic_link:
                              "Register and sign in with a magic link, sent via email to the user.",
                            api_key: "Sign in with an API key.",
                            totp: "Authenticate with a time-based one-time password (TOTP).",
                            recovery_code:
                              "Authenticate with one-time recovery codes as a 2FA fallback."
                          ]
                          |> Enum.map_join("\n", fn {name, description} ->
                            "  * `#{name}` - #{description}"
                          end)

    @moduledoc """
    #{@shortdoc}

    This task composes both the ash_authentication resource-level task and the
    ash_authentication_phoenix Phoenix integration task for each strategy.

    The following strategies are available:

    #{@strategy_explanation}

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    * `--user`, `-u` - The user resource. Defaults to `YourApp.Accounts.User`
    * `--identity-field`, `-i` - The identity field. Defaults to `email`

    ## Password options

      - `--hash-provider` - The hash provider to use, either `bcrypt` or `argon2`. Defaults to `bcrypt`.

    ## TOTP options

      - `--mode`, `-m` - Either `primary` or `2fa`. Defaults to `2fa`.
      - `--name`, `-n` - The name of the TOTP strategy. Defaults to `totp`.
    """

    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :ash,
        example: @example,
        extra_args?: false,
        only: nil,
        positional: [
          strategies: [rest: true]
        ],
        composes: Map.values(@aa_strategy_tasks) ++ Map.values(@aap_strategy_tasks),
        schema: [
          accounts: :string,
          user: :string,
          identity_field: :string,
          hash_provider: :string,
          mode: :string,
          name: :string
        ],
        aliases: [
          a: :accounts,
          u: :user,
          i: :identity_field,
          m: :mode,
          n: :name
        ],
        defaults: [
          identity_field: "email"
        ]
      }
    end

    def igniter(igniter) do
      strategies = igniter.args.positional[:strategies] || []

      invalid_strategy = Enum.find(strategies, &(&1 not in @strategy_names))

      if invalid_strategy do
        Mix.shell().error("""
        Invalid strategy provided: `#{invalid_strategy}`

        Available Strategies:

        #{@strategy_explanation}
        """)

        exit({:shutdown, 1})
      end

      argv = igniter.args.argv_flags

      Enum.reduce(strategies, igniter, fn strategy, igniter ->
        igniter
        |> maybe_compose(strategy, @aa_strategy_tasks, argv)
        |> maybe_compose(strategy, @aap_strategy_tasks, argv)
      end)
    end

    defp maybe_compose(igniter, strategy, task_map, argv) do
      case Map.fetch(task_map, strategy) do
        {:ok, task} -> Igniter.compose_task(igniter, task, argv)
        :error -> igniter
      end
    end
  end
else
  defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy do
    @shortdoc "Adds a strategy to your user resource with Phoenix integration"

    @moduledoc @shortdoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_authentication_phoenix.add_strategy' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
