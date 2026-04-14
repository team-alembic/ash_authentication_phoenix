# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
# credo:disable-for-this-file Credo.Check.Readability.TrailingWhiteSpace
if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshAuthenticationPhoenix.Install do
    use Igniter.Mix.Task

    @example "mix igniter.install ash_authentication_phoenix"

    @shortdoc "Installs AshAuthenticationPhoenix. Invoke with `mix igniter.install ash_authentication_phoenix`"
    @moduledoc """
    #{@shortdoc}

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    * `--accounts` or `-a` - The domain that contains your resources. Defaults to `YourApp.Accounts`.
    * `--user` or `-u` - The resource that represents a user. Defaults to `<accounts>.User`.
    * `--token` or `-t` - The resource that represents a token. Defaults to `<accounts>.Token`.
    """

    @phoenix_strategy_tasks %{
      "password" => "ash_authentication_phoenix.add_strategy.password",
      "magic_link" => "ash_authentication_phoenix.add_strategy.magic_link",
      "totp" => "ash_authentication_phoenix.add_strategy.totp",
      "recovery_code" => "ash_authentication_phoenix.add_strategy.recovery_code"
    }

    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        example: @example,
        group: :ash,
        schema: [
          accounts: :string,
          user: :string,
          token: :string,
          yes: :boolean,
          auth_strategy: :csv,
          mode: :string,
          name: :string
        ],
        composes:
          ["ash_authentication.install", "ash_authentication_phoenix.setup"] ++
            Map.values(@phoenix_strategy_tasks) ++
            ["ash_authentication_phoenix.add_add_on.confirmation"],
        aliases: [
          s: :auth_strategy,
          a: :accounts,
          u: :user,
          t: :token,
          y: :yes,
          m: :mode,
          n: :name
        ]
      }
    end

    def igniter(igniter) do
      options = igniter.args.options
      argv = igniter.args.argv

      options =
        Keyword.put_new_lazy(options, :accounts, fn ->
          Igniter.Project.Module.module_name(igniter, "Accounts")
        end)

      options =
        options
        |> Keyword.put_new_lazy(:user, fn ->
          Module.concat(options[:accounts], User)
        end)
        |> Keyword.put_new_lazy(:token, fn ->
          Module.concat(options[:accounts], Token)
        end)
        |> module_option(:user)
        |> module_option(:accounts)
        |> module_option(:token)

      install? =
        !match?({:ok, _}, Igniter.Project.Deps.get_dep(igniter, :ash_authentication))

      igniter =
        if install? do
          igniter
          |> Igniter.Project.Deps.add_dep({:ash_authentication, "~> 4.1"}, yes: options[:yes])
          |> then(fn
            %{assigns: %{test_mode?: true}} = igniter ->
              igniter

            igniter ->
              Igniter.apply_and_fetch_dependencies(igniter,
                error_on_abort?: true,
                yes: options[:yes],
                yes_to_deps: true
              )
          end)
        else
          igniter
        end

      web_module = Igniter.Libs.Phoenix.web_module(igniter)

      igniter
      |> Igniter.compose_task("ash_authentication_phoenix.setup", [
        "--user",
        inspect(options[:user]),
        "--accounts",
        inspect(options[:accounts])
      ])
      |> maybe_compose_aa_install(install?, argv)
      |> warn_on_missing_modules(options, argv, install?)
      |> compose_phoenix_strategy_tasks(options)
      |> configure_token_resource_notifier(options, web_module)
    end

    defp configure_token_resource_notifier(igniter, options, web_module) do
      token_resource = options[:token]
      endpoint = Module.concat(web_module, Endpoint)

      igniter
      |> Spark.Igniter.add_extension(
        token_resource,
        Ash.Resource,
        :simple_notifiers,
        AshAuthentication.Phoenix.TokenRevocationNotifier
      )
      |> Spark.Igniter.set_option(
        token_resource,
        [:token, :endpoints],
        [endpoint]
      )
      |> Spark.Igniter.set_option(
        token_resource,
        [:token, :live_socket_id_template],
        quote do
          &"users_sessions:#{&1["jti"]}"
        end
      )
    end

    defp warn_on_missing_modules(igniter, options, argv, install?) do
      with {:accounts, {true, igniter}} <-
             {:accounts, Igniter.Project.Module.module_exists(igniter, options[:accounts])},
           {:user, {true, igniter}} <-
             {:user, Igniter.Project.Module.module_exists(igniter, options[:user])},
           {:token, {true, igniter}} <-
             {:token, Igniter.Project.Module.module_exists(igniter, options[:token])} do
        igniter
      else
        {type, {false, igniter}} ->
          handle_missing_module(igniter, options, argv, install?, type)
      end
    end

    defp handle_missing_module(igniter, options, _argv, true = _install?, type) do
      Igniter.add_issue(
        igniter,
        "Could not find #{type} module: #{inspect(options[type])}. Something went wrong with installing ash_authentication."
      )
    end

    defp handle_missing_module(igniter, _options, argv, false = _install?, type) do
      if prompt_to_run_installer?(type) do
        Igniter.compose_task(igniter, "ash_authentication.install", argv)
      else
        igniter
      end
    end

    defp prompt_to_run_installer?(type) do
      Mix.shell().yes?("""
      Could not find #{type} module. Please set the equivalent CLI flag.

      There are two likely causes:

      1. You have an existing #{type} module that does not have the default name.
          If this is the case, quit this command and use the
          --#{type} flag to specify the correct module.
      2. You have not yet run the `ash_authentication` installer.
          To run this, answer Y to this prompt.

      Run the installer now?
      """)
    end

    defp maybe_compose_aa_install(igniter, true = _install?, argv),
      do: Igniter.compose_task(igniter, "ash_authentication.install", argv)

    defp maybe_compose_aa_install(igniter, false = _install?, _argv), do: igniter

    defp compose_phoenix_strategy_tasks(igniter, options) do
      strategies = List.wrap(options[:auth_strategy])
      argv = igniter.args.argv_flags

      Enum.reduce(strategies, igniter, fn strategy, igniter ->
        case Map.fetch(@phoenix_strategy_tasks, to_string(strategy)) do
          {:ok, task} -> Igniter.compose_task(igniter, task, argv)
          :error -> igniter
        end
      end)
    end

    defp module_option(opts, name) do
      case Keyword.fetch(opts, name) do
        {:ok, value} when is_binary(value) ->
          Keyword.put(opts, name, Igniter.Project.Module.parse(value))

        _ ->
          opts
      end
    end
  end
else
  defmodule Mix.Tasks.AshAuthenticationPhoenix.Install do
    use Mix.Task

    @shortdoc "Installs AshAuthenticationPhoenix. Invoke with `mix igniter.install ash_authentication_phoenix`"

    @moduledoc @shortdoc

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_authentication_phoenix.install' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
