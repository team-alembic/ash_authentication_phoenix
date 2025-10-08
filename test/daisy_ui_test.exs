# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.DaisyUITest do
  use ExUnit.Case

  alias AshAuthentication.Phoenix.Overrides.DaisyUI
  alias AshAuthentication.Phoenix.Overrides.Default

  describe "daisyUI overrides" do
    test "has all blocks + keys" do
      default_overrides = Default.overrides()
      daisyui_overrides = DaisyUI.overrides()

      default_by_component = group_overrides_by_component(default_overrides)
      daisyui_by_component = group_overrides_by_component(daisyui_overrides)

      for {component, default_keys} <- default_by_component do
        daisyui_keys = Map.get(daisyui_by_component, component, MapSet.new())
        missing_keys = MapSet.difference(default_keys, daisyui_keys)

        assert MapSet.size(missing_keys) == 0,
               "Component #{inspect(component)}: DaisyUI missing keys #{inspect(MapSet.to_list(missing_keys))}"
      end
    end

    test "has no extra keys" do
      default_structure = get_override_structure(Default)
      daisyui_structure = get_override_structure(DaisyUI)

      for {component, daisyui_keys} <- daisyui_structure do
        default_keys = Map.get(default_structure, component, MapSet.new())
        extra_keys = MapSet.difference(daisyui_keys, default_keys)

        assert MapSet.size(extra_keys) == 0,
               "Component #{inspect(component)}: DaisyUI has extra keys #{inspect(MapSet.to_list(extra_keys))}"
      end
    end
  end

  defp group_overrides_by_component(overrides_map) do
    overrides_map
    |> Enum.group_by(
      fn {{component, _selector}, _value} -> component end,
      fn {{_component, selector}, _value} -> selector end
    )
    |> Map.new(fn {component, selectors} -> {component, MapSet.new(selectors)} end)
  end

  defp get_override_structure(module) do
    group_overrides_by_component(module.overrides())
  end
end
