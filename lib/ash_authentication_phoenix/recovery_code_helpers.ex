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
    case get_recovery_code_strategy(user.__struct__, opts) do
      {:ok, strategy} ->
        codes = Map.get(user, strategy.recovery_codes_relationship_name)

        case codes do
          %Ash.NotLoaded{} ->
            case Ash.load(user, [strategy.recovery_codes_relationship_name]) do
              {:ok, loaded_user} ->
                loaded_user
                |> Map.get(strategy.recovery_codes_relationship_name, [])
                |> Enum.any?()

              _ ->
                false
            end

          codes when is_list(codes) ->
            Enum.any?(codes)

          _ ->
            false
        end

      _ ->
        false
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
      |> Enum.filter(&is_recovery_code_strategy?/1)

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

  defp is_recovery_code_strategy?(%AshAuthentication.Strategy.RecoveryCode{}), do: true
  defp is_recovery_code_strategy?(_), do: false
end
