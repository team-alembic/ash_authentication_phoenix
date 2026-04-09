defmodule AshAuthentication.Phoenix.RecoveryCodeHelpers do
  @moduledoc """
  Helper functions for working with recovery code authentication.

  These helpers can be used in plugs, LiveView on_mount hooks, and templates
  to check if a user has recovery codes configured.

  ## Usage in Templates

      <%= if AshAuthentication.Phoenix.RecoveryCodeHelpers.recovery_codes_configured?(@current_user) do %>
        <span>Recovery codes enabled</span>
      <% end %>
  """

  alias AshAuthentication.Info

  @doc """
  Returns true if the user has recovery codes configured.

  This checks if the user has any recovery codes by loading the configured
  relationship and checking if it is non-empty.

  ## Options

    * `:strategy` - The recovery code strategy to check against. If not provided,
      the first recovery code strategy for the resource will be used.
  """
  @spec recovery_codes_configured?(Ash.Resource.record(), keyword()) :: boolean()
  def recovery_codes_configured?(user, opts \\ []) when is_struct(user) do
    with {:ok, strategy} <- get_recovery_code_strategy(user.__struct__, opts),
         {:ok, codes} <- load_recovery_codes(user, strategy) do
      Enum.any?(codes)
    else
      _ -> false
    end
  end

  defp load_recovery_codes(user, strategy) do
    case Map.get(user, strategy.recovery_codes_relationship_name) do
      %Ash.NotLoaded{} ->
        case Ash.load(user, [strategy.recovery_codes_relationship_name]) do
          {:ok, loaded_user} ->
            {:ok, Map.get(loaded_user, strategy.recovery_codes_relationship_name, [])}

          _ ->
            {:error, :load_failed}
        end

      codes when is_list(codes) ->
        {:ok, codes}

      _ ->
        {:error, :unexpected}
    end
  end

  @doc """
  Returns the recovery code strategy for a resource.

  ## Options

    * `:strategy` - The specific strategy name to look for. If not provided,
      returns the first recovery code strategy found.
  """
  @spec get_recovery_code_strategy(module(), keyword()) ::
          {:ok, struct()} | {:error, :no_recovery_code_strategy}
  def get_recovery_code_strategy(resource, opts \\ []) when is_atom(resource) do
    strategy_name = Keyword.get(opts, :strategy)

    strategies =
      resource
      |> Info.authentication_strategies()
      |> Enum.filter(&recovery_code_strategy?/1)

    case {strategy_name, strategies} do
      {nil, [strategy | _]} ->
        {:ok, strategy}

      {name, strategies} when is_atom(name) ->
        case Enum.find(strategies, &(&1.name == name)) do
          nil -> {:error, :no_recovery_code_strategy}
          strategy -> {:ok, strategy}
        end

      {_, []} ->
        {:error, :no_recovery_code_strategy}
    end
  end

  @doc """
  Returns true if recovery codes are available for the given resource.
  """
  @spec recovery_code_available?(module()) :: boolean()
  def recovery_code_available?(resource) when is_atom(resource) do
    case get_recovery_code_strategy(resource) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp recovery_code_strategy?(%AshAuthentication.Strategy.RecoveryCode{}), do: true
  defp recovery_code_strategy?(_), do: false
end
