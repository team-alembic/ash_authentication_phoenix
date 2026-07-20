# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule Example.Accounts.UserIdentity do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication.UserIdentity],
    domain: Example.Accounts

  user_identity do
    user_resource Example.Accounts.User
  end

  identities do
    identity :unique_on_strategy_and_uid, [:strategy, :uid], pre_check_with: Example.Accounts
  end
end
