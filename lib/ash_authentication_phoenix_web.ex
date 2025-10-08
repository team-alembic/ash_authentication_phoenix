# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Web do
  @moduledoc false

  alias AshAuthentication.Phoenix.{LayoutView, Utils.Flash, Web}

  @doc false
  def view do
    quote do
      use Phoenix.View,
        root: "lib/ash_authentication_phoenix/templates",
        namespace: Web

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [view_module: 1, view_template: 1]

      use Phoenix.Component
    end
  end

  @doc false
  def live_view do
    quote do
      use Phoenix.LiveView, layout: {LayoutView, :live}
      on_mount Flash
    end
  end

  @doc false
  def live_component do
    quote do
      use Phoenix.LiveComponent
      import Flash, only: [put_flash!: 3]
    end
  end

  @doc false
  def component do
    quote do
      use Phoenix.Component
      import Flash, only: [put_flash!: 3]
    end
  end

  @doc """
  Provide a `_gettext` macro for views to wrap around text. Output is a function call to `gettext_switch/3`.
  """
  def maybe_translate do
    quote do
      @spec _gettext(String.t() | nil, Keyword.t()) :: any | no_return
      defmacro _gettext(msgid, bindings \\ [])
      defmacro _gettext(nil, bindings), do: ""

      defmacro _gettext(msgid, bindings) do
        gettext_fn =
          cond do
            Macro.Env.has_var?(__CALLER__, {:assigns, nil}) ->
              quote do: var!(assigns)[:gettext_fn]

            Macro.Env.has_var?(__CALLER__, {:socket, nil}) ->
              quote do: var!(socket).assigns[:gettext_fn]

            true ->
              raise ~S{_gettext requires variable "socket" or "assigns" to exist and be set to a map}
          end

        quote generated: true do
          Web.gettext_switch(unquote(gettext_fn), unquote(msgid), unquote(bindings))
        end
      end

      defmacro _transform_errors do
        quote do
          alias AshPhoenix.FormData.Error

          fn _source, error ->
            if Error.impl_for(error) do
              Error.to_form_error(error)
              |> List.wrap()
              # credo:disable-for-next-line Credo.Check.Refactor.Nesting
              |> Enum.map(fn {field, message, vars} ->
                {field, _gettext(message, vars), vars}
              end)
            else
              error
            end
          end
        end
      end
    end
  end

  @spec gettext_switch(
          gettext_fn :: {module, atom} | nil,
          msgid :: String.t(),
          bindings :: keyword
        ) :: String.t()
  @doc """
  If a translation function is provided, we call that, otherwise return the input untranslated.
  """
  def gettext_switch(_gettext_fn, nil, _bindings), do: ""

  def gettext_switch({module, function}, msgid, bindings)
      when is_atom(module) and is_atom(function) do
    apply(module, function, [msgid, bindings])
  end

  def gettext_switch(nil, msgid, bindings) do
    for {key, value} <- bindings, reduce: msgid do
      acc ->
        value =
          if is_list(value) do
            Enum.map_join(value, ", ", &to_string/1)
          else
            value
          end

        String.replace(acc, "%{#{key}}", to_string(value))
    end
  end

  def gettext_switch(invalid, _msgid, _bindings) do
    raise ArgumentError,
          "gettext_fn: #{inspect(invalid)} is invalid - specify `{module, function}` " <>
            "for a function with a `gettext/2` like signature"
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc. and inject gettext helper.
  """
  defmacro __using__(which) when is_atom(which) do
    quote do
      unquote(apply(__MODULE__, which, []))
      unquote(maybe_translate())
    end
  end
end
