# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule Example.Accounts.OidcConnection do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication.OidcConnection],
    domain: Example.Accounts

  oidc_connection do
    domain Example.Accounts
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:base_url, :client_id, :client_secret, :display_name, :icon_url]
    end

    update :update do
      primary? true
      accept [:base_url, :client_id, :client_secret, :display_name, :icon_url]
    end
  end

  ets do
    private? false
  end
end
