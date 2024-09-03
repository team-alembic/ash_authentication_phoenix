defmodule Example.Accounts.Token do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication.TokenResource],
    domain: Example.Accounts
end
