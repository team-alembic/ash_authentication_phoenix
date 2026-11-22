# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule Example.Accounts.UnstoredUser do
  @moduledoc false

  # A passkey user whose tokens are not stored. Deleting a passkey can then
  # revoke nothing, and a session the passkey started is ended only by the
  # check that its token's passkey still exists. Every other fixture
  # resource stores its tokens, which makes that check a no-op for them.
  #
  # Sign-in is off so the sign-in pages leave the resource out; registration
  # still issues a token naming the passkey, which is all the tests need.

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication],
    domain: Example.Accounts

  actions do
    defaults([:read, :create, :update])
  end

  attributes do
    uuid_primary_key :id
  end

  authentication do
    session_identifier(:jti)

    strategies do
      webauthn :webauthn do
        credential_resource Example.Accounts.UnstoredCredential
        require_identity? false
        sign_in_enabled? false
        rp_id "localhost"
        rp_name "AshAuthenticationPhoenix Test (unstored tokens)"
      end
    end

    tokens do
      enabled?(true)
      token_resource(Example.Accounts.Token)
      store_all_tokens? false
      require_token_presence_for_authentication? false
      signing_secret("fake_secret")
    end
  end

  relationships do
    has_many :webauthn_credentials, Example.Accounts.UnstoredCredential do
      destination_attribute :user_id
    end
  end
end
