# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshAuthenticationPhoenix.AddStrategy.Webauthn do
    use Igniter.Mix.Task

    @example "mix ash_authentication_phoenix.add_strategy webauthn --rp-id example.com --rp-name \"My App\""

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
          name: :string,
          rp_id: :string,
          rp_name: :string,
          origin: :string
        ],
        aliases: [
          a: :accounts,
          u: :user,
          i: :identity_field,
          n: :name
        ],
        defaults: [
          identity_field: "email",
          name: "webauthn"
        ]
      }
    end

    def igniter(igniter) do
      cond do
        not Igniter.exists?(igniter, @app_js_path) ->
          warn_manual(igniter, "Could not find `#{@app_js_path}`.")

        parser_loaded?() ->
          Igniter.update_file(igniter, @app_js_path, &update_app_js_source/1)

        true ->
          install_and_update(igniter)
      end
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
