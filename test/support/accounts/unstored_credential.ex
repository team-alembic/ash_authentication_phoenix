# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule Example.Accounts.UnstoredCredential do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication.WebAuthnCredential],
    domain: Example.Accounts

  webauthn_credential do
    user_resource Example.Accounts.UnstoredUser
  end

  relationships do
    belongs_to :user, Example.Accounts.UnstoredUser, allow_nil?: false, public?: true
  end
end
