defmodule AshAuthentication.Phoenix.Overrides.Info do
  @moduledoc """
  Override introspection.
  """

  @doc """
  Returns a map of all known overridable modules and their overrides.
  """
  @spec all_overridable_modules :: %{required(module) => %{required(atom) => binary}}
  def all_overridable_modules do
    :code.all_loaded()
    |> Stream.map(&elem(&1, 0))
    |> Stream.filter(
      &Spark.implements_behaviour?(&1, AshAuthentication.Phoenix.Overrides.Overridable)
    )
    |> Stream.map(&{&1, &1.__overrides__})
    |> Map.new()
  end
end
