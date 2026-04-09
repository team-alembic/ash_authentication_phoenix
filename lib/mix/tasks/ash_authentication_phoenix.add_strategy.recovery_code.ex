# credo:disable-for-this-file Credo.Check.Design.AliasUsage
if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy.RecoveryCode do
    use Igniter.Mix.Task

    @example "mix ash_authentication_phoenix.add_strategy.recovery_code"

    @shortdoc "Adds Phoenix integration for the recovery code authentication strategy"

    @moduledoc """
    #{@shortdoc}

    Adds recovery code routes to the router and modifies the AuthController
    to handle recovery code verification.

    This task is typically composed by `ash_authentication_phoenix.add_strategy`
    or the `ash_authentication_phoenix.install` task. It can also be run directly
    to add recovery code Phoenix integration to an existing project.

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    * `--user`, `-u` - The user resource. Defaults to `YourApp.Accounts.User`
    * `--name`, `-n` - The name of the recovery code strategy. Defaults to `recovery_code`.
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
          name: :string
        ],
        aliases: [
          a: :accounts,
          u: :user,
          n: :name
        ],
        defaults: [
          name: "recovery_code"
        ]
      }
    end

    def igniter(igniter) do
      options = parse_options(igniter)

      igniter
      |> add_recovery_code_routes(options)
      |> add_cross_link_overrides()
      |> maybe_modify_controller()
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
      |> Keyword.update(:name, :recovery_code, &String.to_atom/1)
      |> Keyword.update!(:accounts, &maybe_parse_module/1)
      |> Keyword.update!(:user, &maybe_parse_module/1)
    end

    defp maybe_parse_module(value) when is_binary(value), do: Igniter.Project.Module.parse(value)
    defp maybe_parse_module(value), do: value

    defp add_recovery_code_routes(igniter, options) do
      {igniter, router} =
        Igniter.Libs.Phoenix.select_router(
          igniter,
          "Which Phoenix router should be modified for recovery code routes?"
        )

      if router do
        user = inspect(options[:user])
        strategy_name = inspect(options[:name])
        overrides = Igniter.Libs.Phoenix.web_module_name(igniter, "AuthOverrides")

        override_module =
          if Igniter.exists?(igniter, "assets/vendor/daisyui.js") do
            AshAuthentication.Phoenix.Overrides.DaisyUI
          else
            AshAuthentication.Phoenix.Overrides.Default
          end

        overrides_opt = "overrides: [#{inspect(overrides)}, #{inspect(override_module)}]"

        routes = """
        recovery_code_verify_route #{user}, #{strategy_name}, auth_routes_prefix: "/auth", #{overrides_opt}
        recovery_code_display_route #{user}, #{strategy_name}, auth_routes_prefix: "/auth", #{overrides_opt}
        """

        Igniter.Libs.Phoenix.append_to_scope(
          igniter,
          "/",
          routes,
          with_pipelines: [:browser],
          arg2: Igniter.Libs.Phoenix.web_module(igniter),
          router: router
        )
      else
        igniter
      end
    end

    defp add_cross_link_overrides(igniter) do
      overrides_module = Igniter.Libs.Phoenix.web_module_name(igniter, "AuthOverrides")
      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, overrides_module)

      if exists? do
        igniter
        |> Igniter.Project.Module.find_and_update_module!(overrides_module, fn zipper ->
          code = """
          override AshAuthentication.Phoenix.Components.Totp.Verify2faForm do
            set :recovery_code_link_path, "/recovery-code-verify"
          end

          override AshAuthentication.Phoenix.Components.RecoveryCode.VerifyForm do
            set :totp_link_path, "/totp-verify"
          end
          """

          {:ok, Igniter.Code.Common.add_code(zipper, code)}
        end)
      else
        Igniter.add_warning(igniter, """
        Could not find AuthOverrides module at #{inspect(overrides_module)}.

        To enable the "Use a recovery code" link on the TOTP verify page, add this
        to your overrides module:

            override AshAuthentication.Phoenix.Components.Totp.Verify2faForm do
              set :recovery_code_link_path, "/recovery-code-verify"
            end

            override AshAuthentication.Phoenix.Components.RecoveryCode.VerifyForm do
              set :totp_link_path, "/totp-verify"
            end
        """)
      end
    end

    defp maybe_modify_controller(igniter) do
      web_module = Igniter.Libs.Phoenix.web_module(igniter)
      controller = Module.concat(web_module, AuthController)

      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, controller)

      if exists? do
        add_confirm_setup_clause(igniter, controller)
      else
        Igniter.add_warning(igniter, """
        Could not find AuthController at #{inspect(controller)}.

        You may want to manually add a success/4 clause that redirects to
        /recovery-codes after successful TOTP setup (confirm_setup phase).
        """)
      end
    end

    defp add_confirm_setup_clause(igniter, controller) do
      Igniter.Project.Module.find_and_update_module!(igniter, controller, fn zipper ->
        case Igniter.Code.Function.move_to_def(zipper, :success, 4, target: :at) do
          {:ok, zipper} ->
            if has_confirm_setup_clause?(zipper) do
              {:ok, zipper}
            else
              {:ok,
               Igniter.Code.Common.add_code(zipper, confirm_setup_clause(), placement: :before)}
            end

          _ ->
            {:ok, zipper}
        end
      end)
    end

    defp has_confirm_setup_clause?(zipper) do
      zipper
      |> Sourceror.Zipper.topmost()
      |> Igniter.Code.Common.move_to(fn z ->
        Igniter.Code.Function.function_call?(z, :def, [2, 3, 4]) and
          source_contains_confirm_setup_guard?(z)
      end)
      |> case do
        {:ok, _} -> true
        :error -> false
      end
    end

    defp source_contains_confirm_setup_guard?(zipper) do
      source = Sourceror.Zipper.node(zipper) |> Macro.to_string()
      String.contains?(source, "confirm_setup")
    end

    defp confirm_setup_clause do
      ~S"""
      def success(conn, {_, :confirm_setup}, user, token) do
        conn
        |> store_in_session(user)
        |> set_live_socket_id(token)
        |> assign(:current_user, user)
        |> redirect(to: ~p"/recovery-codes")
      end
      """
    end
  end
else
  defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy.RecoveryCode do
    @shortdoc "Adds Phoenix integration for the recovery code authentication strategy"

    @moduledoc @shortdoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_authentication_phoenix.add_strategy.recovery_code' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
