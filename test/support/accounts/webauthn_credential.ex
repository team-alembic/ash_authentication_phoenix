# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule Example.Accounts.WebAuthnCredential do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication.WebAuthnCredential],
    domain: Example.Accounts

  webauthn_credential do
    user_resource Example.Accounts.User
  end

  relationships do
    belongs_to :user, Example.Accounts.User, allow_nil?: false, public?: true
  end
end
