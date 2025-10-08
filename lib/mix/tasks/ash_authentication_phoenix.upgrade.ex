# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshAuthenticationPhoenix.Upgrade do
    @moduledoc false

    # credo:disable-for-this-file Credo.Check.Design.AliasUsage
    # credo:disable-for-this-file Credo.Check.Refactor.Nesting

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        # Groups allow for overlapping arguments for tasks by the same author
        # See the generators guide for more.
        group: :ash_authentication_phoenix,
        # *other* dependencies to add
        # i.e `{:foo, "~> 2.0"}`
        adds_deps: [],
        # *other* dependencies to add and call their associated installers, if they exist
        # i.e `{:foo, "~> 2.0"}`
        installs: [],
        # a list of positional arguments, i.e `[:file]`
        positional: [:from, :to],
        # Other tasks your task composes using `Igniter.compose_task`, passing in the CLI argv
        # This ensures your option schema includes options from nested tasks
        composes: [],
        # `OptionParser` schema
        schema: [],
        # Default values for the options in the `schema`
        defaults: [],
        # CLI aliases
        aliases: [],
        # A list of options in the schema that are required
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      positional = igniter.args.positional
      options = igniter.args.options

      upgrades =
        %{
          "2.10.6" => [&change_auth_routes_for_to_auth_routes_for_all_routers/2]
        }

      # For each version that requires a change, add it to this map
      # Each key is a version that points at a list of functions that take an
      # igniter and options (i.e. flags or other custom options).
      # See the upgrades guide for more.
      Igniter.Upgrades.run(igniter, positional.from, positional.to, upgrades,
        custom_opts: options
      )
    end

    defp change_auth_routes_for_to_auth_routes_for_all_routers(igniter, _opts) do
      igniter
      |> Igniter.Libs.Phoenix.list_routers()
      |> then(fn {igniter, routers} ->
        Enum.reduce(routers, igniter, &change_auth_routes_for_to_auth_routes_for_router(&2, &1))
      end)
    end

    defp change_auth_routes_for_to_auth_routes_for_router(igniter, router) do
      igniter
      |> Igniter.Project.Module.find_and_update_module!(router, fn zipper ->
        updated_zipper = transform_all_auth_routes_for_calls(zipper)
        {:ok, updated_zipper}
      end)
    end

    defp transform_all_auth_routes_for_calls(zipper) do
      # Keep transforming until no more auth_routes_for calls are found
      case find_next_auth_routes_for_call(zipper) do
        {:ok, call_zipper} ->
          # Transform this call
          updated_zipper = transform_auth_routes_for_call(call_zipper)
          # Continue searching from the top again
          transform_all_auth_routes_for_calls(Sourceror.Zipper.top(updated_zipper))

        :error ->
          # No more calls found, we're done
          zipper
      end
    end

    defp find_next_auth_routes_for_call(zipper) do
      Igniter.Code.Common.move_to(
        zipper,
        &Igniter.Code.Function.function_call?(&1, :auth_routes_for, 2)
      )
    end

    defp transform_auth_routes_for_call(call_zipper) do
      case Sourceror.Zipper.node(call_zipper) do
        {:auth_routes_for, meta, [resource_ast, opts_ast]} ->
          case extract_controller_from_opts(opts_ast) do
            {:ok, controller_ast} ->
              # Remove the :to option from the opts since controller is now the first parameter
              cleaned_opts_ast = remove_to_option_from_opts(opts_ast)

              # If options list is empty, omit it entirely
              args =
                if opts_empty?(cleaned_opts_ast) do
                  [controller_ast, resource_ast]
                else
                  [controller_ast, resource_ast, cleaned_opts_ast]
                end

              new_call_ast = {:auth_routes, meta, args}
              Sourceror.Zipper.replace(call_zipper, new_call_ast)

            :error ->
              call_zipper
          end

        _ ->
          call_zipper
      end
    end

    defp extract_controller_from_opts(opts_ast) do
      # Create a temporary zipper for the opts AST to use Igniter.Code.Keyword
      temp_zipper = Sourceror.Zipper.zip(opts_ast)

      case Igniter.Code.Keyword.get_key(temp_zipper, :to) do
        {:ok, controller_zipper} ->
          {:ok, Sourceror.Zipper.node(controller_zipper)}

        :error ->
          :error
      end
    end

    defp remove_to_option_from_opts(opts_ast) do
      # Create a temporary zipper for the opts AST to use Igniter.Code.Keyword
      temp_zipper = Sourceror.Zipper.zip(opts_ast)

      case Igniter.Code.Keyword.remove_keyword_key(temp_zipper, :to) do
        {:ok, updated_zipper} ->
          Sourceror.Zipper.node(updated_zipper)

        :error ->
          opts_ast
      end
    end

    defp opts_empty?(opts_ast) do
      case opts_ast do
        [] -> true
        list when is_list(list) -> Enum.empty?(list)
        _ -> false
      end
    end
  end
else
  defmodule Mix.Tasks.AshAuthenticationPhoenix.Upgrade do
    @moduledoc false

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_authentication_phoenix.upgrade' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
