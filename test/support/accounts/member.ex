# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule Example.Accounts.Member do
  @moduledoc """
  A resource configured the way `mix ash_authentication_phoenix.add_strategy
  webauthn --mode 2fa` writes it: a password strategy as the primary factor
  and a WebAuthn strategy that neither registers nor signs in, only
  verifies.

  Its subject name is `member`, so the pages that serve it find the
  signed-in record under `current_member`, not `current_user`.
  """

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication],
    domain: Example.Accounts

  actions do
    defaults([:read])
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  authentication do
    session_identifier(:jti)

    strategies do
      password do
        identity_field(:email)
        hashed_password_field(:hashed_password)
        sign_in_tokens_enabled? true
      end

      webauthn :webauthn do
        credential_resource Example.Accounts.MemberCredential
        identity_field :email
        rp_id "localhost"
        rp_name "AshAuthenticationPhoenix Dev (second factor)"
        registration_enabled? false
        sign_in_enabled? false
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

  identities do
    identity(:unique_email, [:email],
      pre_check_with: Example.Accounts,
      eager_check_with: Example.Accounts
    )
  end

  relationships do
    has_many :webauthn_credentials, Example.Accounts.MemberCredential do
      destination_attribute :user_id
    end
  end
end
