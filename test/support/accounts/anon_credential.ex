# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule Example.Accounts.AnonCredential do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication.WebAuthnCredential],
    domain: Example.Accounts

  webauthn_credential do
    user_resource Example.Accounts.AnonUser
  end

  relationships do
    belongs_to :user, Example.Accounts.AnonUser, allow_nil?: false, public?: true
  end
end
