# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy.Webauthn do
    use Igniter.Mix.Task

    @example "mix ash_authentication_phoenix.add_strategy webauthn"

    @shortdoc "Adds Phoenix integration for the WebAuthn authentication strategy"

    @hooks ["WebAuthnRegistrationHook", "WebAuthnAuthenticationHook", "WebAuthnSupportHook"]
    @hooks_module "ash_authentication_phoenix/priv/static/webauthn_hooks.js"
    @import_line ~s|import { #{Enum.join(@hooks, ", ")} } from "#{@hooks_module}"|
    @app_js_path "assets/js/app.js"

    @manual_instructions """
    Add the following to your `#{@app_js_path}`:

        #{@import_line}

    …and register the hooks on your `LiveSocket`:

        let liveSocket = new LiveSocket("/live", Socket, {
          // ...
          hooks: { #{Enum.join(@hooks, ", ")} }
        })
    """

    @igniter_js_dep {:igniter_js, "~> 0.4"}

    @could_not_install_igniter_js """
    Could not install `igniter_js`. Add it to your dependencies manually and
    re-run this task to have `#{@app_js_path}` updated for you:

        #{inspect(@igniter_js_dep)}
    """

    @moduledoc """
    #{@shortdoc}

    Wires the LiveView hook imports and registrations required by the WebAuthn UI
    components into your `#{@app_js_path}` file.

    The browser-side hooks drive the WebAuthn ceremony — they invoke
    `navigator.credentials.create` / `.get` and return the signed assertion to
    the server. Without them, the WebAuthn components will not function.

    Automatic wiring is performed via an AST codemod powered by
    [`igniter_js`](https://hex.pm/packages/igniter_js). If `igniter_js` is not
    already a dependency, the task adds it to your `mix.exs`, fetches and
    compiles it, then continues with the codemod in the same run.

    Because the codemod re-emits the file in its canonical form, expect cosmetic
    formatting changes (e.g. semicolons, indentation) on the first run.
    Re-running the task is a no-op once the hooks are wired up.

    ## Example

    ```bash
    #{@example}
    ```
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
          mode: "primary",
          name: "webauthn"
        ]
      }
    end

    def igniter(igniter) do
      mode = parse_mode(igniter.args.options[:mode] || "primary")

      igniter
      |> wire_js_hooks()
      |> add_2fa_routes(mode)
      |> maybe_modify_controller(mode)
    end

    defp parse_mode("primary"), do: :primary
    defp parse_mode("2fa"), do: :"2fa"
    defp parse_mode(:primary), do: :primary
    defp parse_mode(:"2fa"), do: :"2fa"

    defp parse_mode(other) do
      Mix.shell().error("""
      Invalid `--mode` value: `#{inspect(other)}`.

      Available modes:

        * `primary` (default) — passkeys are the primary credential.
        * `2fa` — passkeys are a second factor on top of another primary
          credential.
      """)

      exit({:shutdown, 1})
    end

    defp wire_js_hooks(igniter) do
      cond do
        not Igniter.exists?(igniter, @app_js_path) ->
          warn_manual(igniter, "Could not find `#{@app_js_path}`.")

        parser_loaded?() ->
          Igniter.update_file(igniter, @app_js_path, &update_app_js_source/1)

        true ->
          install_and_update(igniter)
      end
    end

    defp add_2fa_routes(igniter, :primary), do: igniter

    defp add_2fa_routes(igniter, :"2fa") do
      {igniter, router} =
        Igniter.Libs.Phoenix.select_router(
          igniter,
          "Which Phoenix router should be modified for the WebAuthn 2FA routes?"
        )

      if router do
        web_module = Igniter.Libs.Phoenix.web_module(igniter)
        user = inspect(Module.concat(web_module, "Accounts.User"))
        # The user resource isn't easy to derive from the AAP installer alone, so
        # rely on Igniter's web-module convention. Users can edit the args after.
        user =
          case igniter.args.options[:user] do
            value when is_binary(value) -> value
            _ -> user
          end

        strategy_name = inspect(igniter.args.options[:name] || "webauthn")
        overrides = Igniter.Libs.Phoenix.web_module_name(igniter, "AuthOverrides")

        override_module =
          if Igniter.exists?(igniter, "assets/vendor/daisyui.js") do
            AshAuthentication.Phoenix.Overrides.DaisyUI
          else
            AshAuthentication.Phoenix.Overrides.Default
          end

        overrides_opt = "overrides: [#{inspect(overrides)}, #{inspect(override_module)}]"

        routes = """
        webauthn_2fa_route #{user}, #{strategy_name}, auth_routes_prefix: "/auth", #{overrides_opt}
        webauthn_setup_route #{user}, #{strategy_name}, auth_routes_prefix: "/auth", #{overrides_opt}
        """

        Igniter.Libs.Phoenix.append_to_scope(
          igniter,
          "/",
          routes,
          with_pipelines: [:browser],
          arg2: web_module,
          router: router
        )
      else
        igniter
      end
    end

    defp maybe_modify_controller(igniter, :primary), do: igniter

    defp maybe_modify_controller(igniter, :"2fa") do
      web_module = Igniter.Libs.Phoenix.web_module(igniter)
      controller = Module.concat(web_module, AuthController)

      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, controller)

      if exists? do
        replace_controller_success(igniter, controller)
      else
        Igniter.add_warning(igniter, """
        Could not find AuthController at #{inspect(controller)}.

        You will need to manually update your auth controller's `success/4`
        function to handle WebAuthn 2FA redirects. See the
        Passkeys-as-2FA tutorial for details.
        """)
      end
    end

    defp replace_controller_success(igniter, controller) do
      Igniter.Project.Module.find_and_update_module!(igniter, controller, fn zipper ->
        case Igniter.Code.Function.move_to_def(zipper, :success, 4, target: :at) do
          {:ok, zipper} -> maybe_insert_webauthn_clauses(zipper)
          _ -> {:ok, zipper}
        end
      end)
    end

    defp maybe_insert_webauthn_clauses(zipper) do
      if has_webauthn_clauses?(zipper) do
        {:ok, zipper}
      else
        {:ok, Igniter.Code.Common.add_code(zipper, webauthn_clauses(), placement: :before)}
      end
    end

    defp has_webauthn_clauses?(zipper) do
      zipper
      |> Sourceror.Zipper.topmost()
      |> Igniter.Code.Common.move_to(fn z ->
        Igniter.Code.Function.function_call?(z, :def, [2, 3, 4]) and
          source_contains_webauthn_guard?(z)
      end)
      |> case do
        {:ok, _} -> true
        :error -> false
      end
    end

    defp source_contains_webauthn_guard?(zipper) do
      source = Sourceror.Zipper.node(zipper) |> Macro.to_string()
      String.contains?(source, "webauthn_configured?")
    end

    defp webauthn_clauses do
      webauthn_sign_in_clause() <> "\n" <> webauthn_register_clause()
    end

    defp webauthn_sign_in_clause do
      ~S"""
      def success(conn, {_, phase} = _activity, user, token)
          when phase in [:sign_in, :sign_in_with_token] do
        return_to = get_session(conn, :return_to) || ~p"/"

        if AshAuthentication.Phoenix.WebAuthnHelpers.webauthn_configured?(user) do
          conn
          |> store_in_session(user)
          |> set_live_socket_id(token)
          |> assign(:current_user, user)
          |> put_session(:return_to, return_to)
          |> redirect(to: ~p"/webauthn-verify/#{token}")
        else
          conn
          |> store_in_session(user)
          |> set_live_socket_id(token)
          |> assign(:current_user, user)
          |> put_session(:return_to, return_to)
          |> redirect(to: ~p"/webauthn-setup")
        end
      end
      """
    end

    defp webauthn_register_clause do
      ~S"""
      def success(conn, {_, :register}, user, token) do
        return_to = get_session(conn, :return_to) || ~p"/"

        conn
        |> store_in_session(user)
        |> set_live_socket_id(token)
        |> assign(:current_user, user)
        |> put_session(:return_to, return_to)
        |> redirect(to: ~p"/webauthn-setup")
      end
      """
    end

    defp install_and_update(igniter) do
      igniter =
        igniter
        |> Igniter.Project.Deps.add_dep(@igniter_js_dep, on_exists: :skip)
        |> Igniter.apply_and_fetch_dependencies(
          operation: "compiling igniter_js for WebAuthn JS hook wiring"
        )

      if parser_loaded?() do
        Igniter.update_file(igniter, @app_js_path, &update_app_js_source/1)
      else
        Igniter.add_warning(
          igniter,
          @could_not_install_igniter_js <> "\n" <> @manual_instructions
        )
      end
    end

    defp update_app_js_source(source) do
      content = Rewrite.Source.get(source, :content)

      cond do
        already_wired_up?(content) ->
          source

        not call_parser(:exist_live_socket?, [content, :content]) ->
          {:warning,
           manual_instructions(
             "Could not find a `liveSocket = new LiveSocket(...)` declaration in `#{@app_js_path}`."
           )}

        true ->
          transform_content(source, content)
      end
    end

    defp already_wired_up?(content) do
      String.contains?(content, @hooks_module) and
        Enum.all?(@hooks, &String.contains?(content, &1))
    end

    defp transform_content(source, content) do
      with {:ok, _, content} <-
             call_parser(:insert_imports, [content, @import_line, :content]),
           {:ok, _, content} <-
             call_parser(:extend_hook_object, [content, @hooks, :content]) do
        Rewrite.Source.update(source, :content, content)
      else
        {:error, _, message} ->
          {:warning,
           manual_instructions("Could not update `#{@app_js_path}` automatically: #{message}")}
      end
    end

    defp warn_manual(igniter, reason) do
      Igniter.add_warning(igniter, manual_instructions(reason))
    end

    defp manual_instructions(reason) do
      "#{reason}\n\n#{@manual_instructions}"
    end

    defp parser_loaded?, do: Code.ensure_loaded?(parser_module())

    defp call_parser(fun, args), do: apply(parser_module(), fun, args)

    defp parser_module, do: Module.concat([IgniterJs, Parsers, Javascript, Parser])
  end
else
  defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy.Webauthn do
    @shortdoc "Adds Phoenix integration for the WebAuthn authentication strategy"

    @moduledoc @shortdoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_authentication_phoenix.add_strategy.webauthn' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
