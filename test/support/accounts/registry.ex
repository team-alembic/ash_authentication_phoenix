defmodule Example.Accounts.Registry do
  @moduledoc false
  use Ash.Registry, extensions: [Ash.Registry.ResourceValidations]

  entries do
    entry Example.Accounts.User
    entry Example.Accounts.Token
  end
end
