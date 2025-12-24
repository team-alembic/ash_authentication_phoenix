defmodule AshAuthentication.Phoenix.Test.FilterInviteOverride do
  use AshAuthentication.Phoenix.Overrides
  alias AshAuthentication.Phoenix.Components

  def filter_strategy(strategy), do: strategy.name != :invite

  override Components.SignIn do
    set :filter_strategy, &__MODULE__.filter_strategy/1
  end
end
