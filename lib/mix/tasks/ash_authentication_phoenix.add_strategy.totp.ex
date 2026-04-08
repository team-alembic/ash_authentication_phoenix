# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy.Totp do
    use Igniter.Mix.Task

    @example "mix ash_authentication_phoenix.add_strategy totp"

    @shortdoc "Adds Phoenix integration for the TOTP authentication strategy"

    @moduledoc """
    #{@shortdoc}

    Modifies the AuthController to handle TOTP 2FA redirects and emits
    route setup instructions.

    This task is typically composed by `ash_authentication_phoenix.add_strategy`
    or the `ash_authentication_phoenix.install` task. It can also be run directly
    to add TOTP Phoenix integration to an existing project.

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    * `--user`, `-u` - The user resource. Defaults to `YourApp.Accounts.User`
    * `--mode`, `-m` - Either `primary` or `2fa`. Defaults to `2fa`.
    * `--name`, `-n` - The name of the TOTP strategy. Defaults to `totp`.
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
          identity_field: :string,
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
          identity_field: "email",
          mode: "2fa",
          name: "totp"
        ]
      }
    end

    def igniter(igniter) do
      options = parse_options(igniter)

      igniter
      |> Igniter.Project.Deps.add_dep({:eqrcode, "~> 0.1"})
      |> add_totp_routes(options)
      |> maybe_modify_controller(options)
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
      |> Keyword.update(:mode, :"2fa", &String.to_atom/1)
      |> Keyword.update(:name, :totp, &String.to_atom/1)
      |> Keyword.update!(:accounts, &maybe_parse_module/1)
      |> Keyword.update!(:user, &maybe_parse_module/1)
    end

    defp maybe_parse_module(value) when is_binary(value), do: Igniter.Project.Module.parse(value)
    defp maybe_parse_module(value), do: value

    defp add_totp_routes(igniter, options) do
      {igniter, router} =
        Igniter.Libs.Phoenix.select_router(
          igniter,
          "Which Phoenix router should be modified for TOTP routes?"
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

        routes =
          if options[:mode] == :"2fa" do
            """
            totp_2fa_route #{user}, #{strategy_name}, auth_routes_prefix: "/auth", #{overrides_opt}
            totp_setup_route #{user}, #{strategy_name}, auth_routes_prefix: "/auth", #{overrides_opt}
            """
          else
            """
            totp_setup_route #{user}, #{strategy_name}, auth_routes_prefix: "/auth", #{overrides_opt}
            """
          end

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

    defp maybe_modify_controller(igniter, options) do
      if options[:mode] == :"2fa" do
        modify_controller_for_2fa(igniter)
      else
        igniter
      end
    end

    defp modify_controller_for_2fa(igniter) do
      web_module = Igniter.Libs.Phoenix.web_module(igniter)
      controller = Module.concat(web_module, AuthController)

      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, controller)

      if exists? do
        replace_controller_success(igniter, controller)
      else
        Igniter.add_warning(igniter, """
        Could not find AuthController at #{inspect(controller)}.

        You will need to manually update your auth controller's success/4 function
        to handle TOTP 2FA redirects. See the TOTP tutorial for details.
        """)
      end
    end

    defp replace_controller_success(igniter, controller) do
      Igniter.Project.Module.find_and_update_module!(igniter, controller, fn zipper ->
        case Igniter.Code.Function.move_to_def(zipper, :success, 4, target: :at) do
          {:ok, zipper} -> maybe_insert_totp_clauses(zipper)
          _ -> {:ok, zipper}
        end
      end)
    end

    defp maybe_insert_totp_clauses(zipper) do
      if has_totp_clauses?(zipper) do
        {:ok, zipper}
      else
        {:ok, Igniter.Code.Common.add_code(zipper, totp_clauses(), placement: :before)}
      end
    end

    defp totp_clauses do
      totp_sign_in_clause() <> "\n" <> totp_registration_clause()
    end

    defp has_totp_clauses?(zipper) do
      zipper
      |> Sourceror.Zipper.topmost()
      |> Igniter.Code.Common.move_to(fn z ->
        Igniter.Code.Function.function_call?(z, :def, [2, 3, 4]) and
          source_contains_totp_guard?(z)
      end)
      |> case do
        {:ok, _} -> true
        :error -> false
      end
    end

    defp source_contains_totp_guard?(zipper) do
      source = Sourceror.Zipper.node(zipper) |> Macro.to_string()
      String.contains?(source, "when phase in [:sign_in, :sign_in_with_token]")
    end

    defp totp_sign_in_clause do
      ~S"""
      def success(conn, {_, phase} = _activity, user, token)
          when phase in [:sign_in, :sign_in_with_token] do
        return_to = get_session(conn, :return_to) || ~p"/"

        if AshAuthentication.Phoenix.TotpHelpers.totp_configured?(user) do
          conn
          |> store_in_session(user)
          |> set_live_socket_id(token)
          |> assign(:current_user, user)
          |> put_session(:return_to, return_to)
          |> redirect(to: ~p"/totp-verify/#{token}")
        else
          conn
          |> store_in_session(user)
          |> set_live_socket_id(token)
          |> assign(:current_user, user)
          |> put_session(:return_to, return_to)
          |> redirect(to: ~p"/totp-setup")
        end
      end
      """
    end

    defp totp_registration_clause do
      ~S"""
      def success(conn, {_, :register}, user, token) do
        return_to = get_session(conn, :return_to) || ~p"/"

        conn
        |> store_in_session(user)
        |> set_live_socket_id(token)
        |> assign(:current_user, user)
        |> put_session(:return_to, return_to)
        |> redirect(to: ~p"/totp-setup")
      end
      """
    end
  end
else
  defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy.Totp do
    @shortdoc "Adds Phoenix integration for the TOTP authentication strategy"

    @moduledoc @shortdoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_authentication_phoenix.add_strategy.totp' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
