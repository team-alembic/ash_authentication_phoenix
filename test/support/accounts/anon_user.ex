# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule Example.Accounts.AnonUser do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication],
    domain: Example.Accounts

  actions do
    defaults([:read, :create, :update])
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  authentication do
    session_identifier(:jti)

    strategies do
      webauthn :webauthn do
        credential_resource Example.Accounts.AnonCredential
        require_identity? false
        rp_id "localhost"
        rp_name "AshAuthenticationPhoenix Dev (passkey-only)"
        origin fn _resource, _opts -> {:ok, DevWeb.Endpoint.url()} end
        # A machine with no authenticator of its own can still enrol and use a
        # passkey held on a phone, which is the point of passkey-only mode.
        # The QR scan, Bluetooth handshake and prompt on the second device
        # don't fit the default 60s timeout.
        hints [:hybrid, :security_key]
        timeout 300_000
      end
    end

    tokens do
      enabled?(true)
      token_resource(Example.Accounts.Token)
      store_all_tokens? true
      require_token_presence_for_authentication? false
      signing_secret("fake_secret")
    end
  end

  relationships do
    has_many :webauthn_credentials, Example.Accounts.AnonCredential do
      destination_attribute :user_id
    end
  end
end
