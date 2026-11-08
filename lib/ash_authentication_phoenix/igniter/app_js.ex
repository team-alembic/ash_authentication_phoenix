# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

if Code.ensure_loaded?(Igniter) do
  defmodule AshAuthentication.Phoenix.Igniter.AppJs do
    @moduledoc false
    # Wires LiveView hook imports and registrations into an `app.js`, changing
    # only the characters it adds.
    #
    # `igniter_js` parses the file into an ESTree, whose node positions are
    # UTF-16 code unit offsets into the source. Every edit is a splice at one
    # of those offsets, so the rest of the file — quoting, indentation,
    # comments, semicolons — comes out exactly as it went in. The alternative,
    # igniter_js's own codemods, re-emit the whole file in their canonical
    # style.

    @typep offset :: non_neg_integer
    # An insertion at an offset, or a replacement of the range between two.
    @typep edit :: {offset, String.t()} | {offset, offset, String.t()}
    @typep estree :: map

    @doc """
    Imports `hooks` from `module` and registers them on the `LiveSocket`.

    Returns `:unchanged` when every hook is already imported and registered,
    `{:ok, content}` with the edited file otherwise, and `{:error, reason}`
    when the file can't be parsed, declares no `new LiveSocket(...)`, or
    constructs it without an options object.

    Hooks already imported or registered are left alone, so a file that is
    half wired up ends up whole. Every edit matches the surrounding style:
    a multi-line `hooks` object gets one hook per line at its indentation, a
    one-line object stays on one line, and a trailing comma stays trailing.
    """
    @spec wire_hooks(String.t(), String.t(), [String.t()]) ::
            {:ok, String.t()} | :unchanged | {:error, String.t()}
    def wire_hooks(content, module, hooks) do
      with {:ok, program} <- parse(content),
           {:ok, options} <- live_socket_options(program) do
        edits =
          import_edits(program, content, module, hooks) ++ hooks_edits(options, content, hooks)

        case edits do
          [] -> :unchanged
          edits -> {:ok, splice(content, edits)}
        end
      end
    end

    # -- parsing ---------------------------------------------------------------

    # `igniter_js` is optional, so the module is named at runtime.
    defp parser, do: Module.concat([IgniterJs, Parsers, Javascript, Parser])

    defp parse(content) do
      case parser().ast_to_estree(content, :content) do
        {:ok, _, %{"errors" => [error | _]}} ->
          {:error, "could not parse it: #{error["message"]}"}

        {:ok, _, %{"program" => program}} ->
          {:ok, program}

        {:error, _, message} ->
          {:error, "could not parse it: #{message}"}
      end
    end

    defp live_socket_options(program) do
      with {:ok, call} <- find_node(program, &live_socket_call?/1),
           %{"type" => "ObjectExpression"} = options <-
             call["arguments"] |> Enum.reverse() |> Enum.find(&(&1["type"] == "ObjectExpression")) do
        {:ok, options}
      else
        :error -> {:error, "could not find a `liveSocket = new LiveSocket(...)` declaration"}
        nil -> {:error, "`new LiveSocket(...)` is called without an options object"}
      end
    end

    defp live_socket_call?(%{"type" => "NewExpression", "callee" => %{"name" => "LiveSocket"}}),
      do: true

    defp live_socket_call?(_), do: false

    defp find_node(%{} = node, predicate) do
      if predicate.(node) do
        {:ok, node}
      else
        node |> Map.values() |> find_in(predicate)
      end
    end

    defp find_node(nodes, predicate) when is_list(nodes), do: find_in(nodes, predicate)
    defp find_node(_, _), do: :error

    defp find_in(children, predicate) do
      Enum.find_value(children, :error, fn child ->
        case find_node(child, predicate) do
          {:ok, node} -> {:ok, node}
          :error -> nil
        end
      end)
    end

    # -- the import ------------------------------------------------------------

    @spec import_edits(estree, String.t(), String.t(), [String.t()]) :: [edit]
    defp import_edits(program, content, module, hooks) do
      imports = Enum.filter(program["body"], &(&1["type"] == "ImportDeclaration"))

      case Enum.find(imports, &(&1["source"]["value"] == module)) do
        nil -> [new_import(imports, content, module, hooks)]
        declaration -> extend_import(declaration, imports, content, module, hooks)
      end
    end

    defp new_import(imports, content, module, hooks) do
      line = import_line(module, hooks) <> semicolon(imports, content)

      case List.last(imports) do
        nil -> {0, line <> "\n"}
        last -> {end_of_line(content, last["end"]), "\n" <> line}
      end
    end

    defp extend_import(declaration, imports, content, module, hooks) do
      specifiers = declaration["specifiers"]
      imported = Enum.map(specifiers, & &1["imported"]["name"])

      case {hooks -- imported, List.last(specifiers)} do
        {[], _} ->
          []

        # `import "module"` imports nothing; give the hooks a line of their own.
        {missing, nil} ->
          [new_import(imports, content, module, missing)]

        {missing, last} ->
          [{last["end"], ", " <> Enum.join(missing, ", ")}]
      end
    end

    defp import_line(module, hooks), do: ~s|import { #{Enum.join(hooks, ", ")} } from "#{module}"|

    defp semicolon(imports, content) do
      if Enum.any?(imports, &String.ends_with?(source(content, &1), ";")), do: ";", else: ""
    end

    # -- the hooks -------------------------------------------------------------

    @spec hooks_edits(estree, String.t(), [String.t()]) :: [edit]
    defp hooks_edits(options, content, hooks) do
      case Enum.find(options["properties"], &property_named?(&1, "hooks")) do
        nil ->
          [add_hooks_property(options, content, hooks)]

        %{"shorthand" => true} = property ->
          # `{ hooks }` — the hooks object lives in a variable of that name.
          [{property["start"], property["end"], "hooks: { ...hooks, #{Enum.join(hooks, ", ")} }"}]

        %{"value" => %{"type" => "ObjectExpression"} = object} ->
          extend_object(object, content, hooks -- property_names(object))

        %{"value" => value} ->
          # `hooks: Hooks`, `hooks: makeHooks()` — spread whatever it is.
          [
            {value["start"], value["end"],
             "{ ...#{source(content, value)}, #{Enum.join(hooks, ", ")} }"}
          ]
      end
    end

    defp extend_object(_object, _content, []), do: []

    defp extend_object(%{"properties" => []} = object, _content, hooks) do
      [{object["start"] + 1, " #{Enum.join(hooks, ", ")} "}]
    end

    defp extend_object(%{"properties" => properties} = object, content, hooks) do
      last = List.last(properties)

      if multiline?(content, object) do
        indent = line_indent(content, hd(properties)["start"])
        [{last["end"], Enum.map_join(hooks, &(",\n" <> indent <> &1))}]
      else
        [{last["end"], ", " <> Enum.join(hooks, ", ")}]
      end
    end

    defp add_hooks_property(%{"properties" => []} = options, _content, hooks) do
      {options["start"] + 1, " hooks: { #{Enum.join(hooks, ", ")} } "}
    end

    defp add_hooks_property(%{"properties" => properties} = options, content, hooks) do
      last = List.last(properties)

      if multiline?(content, options) do
        indent = line_indent(content, hd(properties)["start"])
        inner = indent <> indent_unit(content, options, indent)
        comma = if trailing_comma?(content, options), do: ",", else: ""

        object = Enum.map_join(hooks, ",\n", &(inner <> &1)) <> comma

        {last["end"], ",\n#{indent}hooks: {\n#{object}\n#{indent}}"}
      else
        {last["end"], ", hooks: { #{Enum.join(hooks, ", ")} }"}
      end
    end

    defp property_named?(%{"type" => "Property", "computed" => false} = property, name),
      do: property_name(property) == name

    defp property_named?(_, _), do: false

    defp property_names(%{"properties" => properties}) do
      properties
      |> Enum.filter(&(&1["type"] == "Property"))
      |> Enum.map(&property_name/1)
    end

    defp property_name(%{"key" => %{"type" => "Identifier", "name" => name}}), do: name
    defp property_name(%{"key" => %{"type" => "Literal", "value" => value}}), do: to_string(value)
    defp property_name(_), do: nil

    # -- source text, addressed in UTF-16 code units ---------------------------

    defp source(content, %{"start" => start, "end" => stop}) do
      content |> to_utf16() |> binary_part(start * 2, (stop - start) * 2) |> from_utf16()
    end

    defp before(content, offset) do
      content |> to_utf16() |> binary_part(0, offset * 2) |> from_utf16()
    end

    defp from(content, offset) do
      utf16 = to_utf16(content)
      utf16 |> binary_part(offset * 2, byte_size(utf16) - offset * 2) |> from_utf16()
    end

    defp multiline?(content, node), do: String.contains?(source(content, node), "\n")

    # `{a, b,}` — a comma after the last property.
    defp trailing_comma?(content, %{"properties" => properties} = object) do
      content
      |> source(%{"start" => List.last(properties)["end"], "end" => object["end"]})
      |> String.contains?(",")
    end

    # The whitespace opening the line that `offset` is on.
    defp line_indent(content, offset) do
      line = content |> before(offset) |> String.split("\n") |> List.last()
      String.slice(line, 0, String.length(line) - String.length(String.trim_leading(line)))
    end

    # How much deeper the properties sit than the line opening the object, so
    # a nested object can go one level further. Two spaces when the file
    # doesn't say.
    defp indent_unit(content, object, property_indent) do
      case String.replace_prefix(property_indent, line_indent(content, object["start"]), "") do
        "" -> "  "
        unit -> unit
      end
    end

    defp end_of_line(content, offset) do
      case content |> from(offset) |> String.split("\n", parts: 2) do
        [line, _] -> offset + utf16_length(line)
        [_] -> utf16_length(content)
      end
    end

    @spec splice(String.t(), [edit]) :: String.t()
    defp splice(content, edits) do
      edits
      |> Enum.map(fn
        {offset, insert} -> {offset, offset, insert}
        {_, _, _} = edit -> edit
      end)
      |> Enum.sort_by(&elem(&1, 0), :desc)
      |> Enum.reduce(to_utf16(content), fn {start, stop, insert}, utf16 ->
        {head, rest} = :erlang.split_binary(utf16, start * 2)
        {_, tail} = :erlang.split_binary(rest, (stop - start) * 2)
        head <> to_utf16(insert) <> tail
      end)
      |> from_utf16()
    end

    defp to_utf16(string), do: :unicode.characters_to_binary(string, :utf8, {:utf16, :big})
    defp from_utf16(binary), do: :unicode.characters_to_binary(binary, {:utf16, :big}, :utf8)
    defp utf16_length(string), do: string |> to_utf16() |> byte_size() |> div(2)
  end
end
