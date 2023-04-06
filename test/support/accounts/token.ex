defmodule Example.Accounts.Token do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication.TokenResource]

  token do
    api Example.Accounts
  end

  actions do
    defaults [:read]
  end
end
