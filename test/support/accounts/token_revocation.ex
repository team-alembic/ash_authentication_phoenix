defmodule Example.Accounts.TokenRevocation do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication.TokenRevocation]

  revocation do
    api Example.Accounts
  end
end
