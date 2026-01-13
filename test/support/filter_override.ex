# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Test.FilterInviteOverride do
  @moduledoc false
  use AshAuthentication.Phoenix.Overrides
  alias AshAuthentication.Phoenix.Components

  def filter_strategy(strategy), do: strategy.name != :invite

  override Components.SignIn do
    set :filter_strategy, &__MODULE__.filter_strategy/1
  end
end
