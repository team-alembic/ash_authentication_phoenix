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

  attributes do
    # The extension scaffolds neither: with a creation timestamp the panel
    # shows when a passkey was added, and with no default label a passkey
    # named nothing falls back to the panel's `default_label_text`.
    create_timestamp :inserted_at
    attribute :label, :string, allow_nil?: true, writable?: true, public?: true
  end

  relationships do
    belongs_to :user, Example.Accounts.User, allow_nil?: false, public?: true
  end
end
