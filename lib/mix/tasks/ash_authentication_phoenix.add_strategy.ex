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
      "otp" => "ash_authentication.add_strategy.otp",
      "api_key" => "ash_authentication.add_strategy.api_key",
      "totp" => "ash_authentication.add_strategy.totp",
      "recovery_code" => "ash_authentication.add_strategy.recovery_code",
      "webauthn" => "ash_authentication.add_strategy.webauthn",
      "github" => "ash_authentication.add_strategy.github",
      "google" => "ash_authentication.add_strategy.google",
      "apple" => "ash_authentication.add_strategy.apple",
      "auth0" => "ash_authentication.add_strategy.auth0",
      "microsoft" => "ash_authentication.add_strategy.microsoft",
      "slack" => "ash_authentication.add_strategy.slack",
      "oidc" => "ash_authentication.add_strategy.oidc",
      "oauth2" => "ash_authentication.add_strategy.oauth2"
    }

    @aap_strategy_tasks %{
      "password" => "ash_authentication_phoenix.add_strategy.password",
      "magic_link" => "ash_authentication_phoenix.add_strategy.magic_link",
      "otp" => "ash_authentication_phoenix.add_strategy.otp",
      "totp" => "ash_authentication_phoenix.add_strategy.totp",
      "recovery_code" => "ash_authentication_phoenix.add_strategy.recovery_code",
      "webauthn" => "ash_authentication_phoenix.add_strategy.webauthn",
      "github" => "ash_authentication_phoenix.setup",
      "google" => "ash_authentication_phoenix.setup",
      "apple" => "ash_authentication_phoenix.setup",
      "auth0" => "ash_authentication_phoenix.setup",
      "microsoft" => "ash_authentication_phoenix.setup",
      "slack" => "ash_authentication_phoenix.setup",
      "oidc" => "ash_authentication_phoenix.setup",
      "oauth2" => "ash_authentication_phoenix.setup"
    }

    @strategy_names Map.keys(@aa_strategy_tasks)

    @strategy_explanation [
                            password:
                              "Register and sign in with a username/email and a password.",
                            magic_link:
                              "Register and sign in with a magic link, sent via email to the user.",
                            otp: "Sign in with a short one-time password sent via email or SMS.",
                            api_key: "Sign in with an API key.",
                            totp: "Authenticate with a time-based one-time password (TOTP).",
                            recovery_code:
                              "Authenticate with one-time recovery codes as a 2FA fallback.",
                            webauthn:
                              "Authenticate with hardware security keys, platform authenticators or passkeys.",
                            github: "Sign in with GitHub.",
                            google: "Sign in with Google.",
                            apple: "Sign in with Apple.",
                            auth0: "Sign in with Auth0.",
                            microsoft: "Sign in with Microsoft.",
                            slack: "Sign in with Slack.",
                            oidc: "Sign in with a generic OpenID Connect provider.",
                            oauth2: "Sign in with a generic OAuth2 provider."
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

    ## WebAuthn options

      - `--rp-id` - The Relying Party ID (your domain, e.g. `example.com`). Required.
      - `--rp-name` - The Relying Party display name shown to the user during registration. Required.
      - `--origin` - The full origin URL (e.g. `https://example.com` or `https://localhost:4001`). Optional.
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
          name: :string,
          base_url: :string,
          authorize_url: :string,
          token_url: :string,
          user_url: :string,
          team_id: :string,
          rp_id: :string,
          rp_name: :string,
          origin: :string
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
