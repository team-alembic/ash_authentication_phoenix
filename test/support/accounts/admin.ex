# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule Example.Accounts.Admin do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication],
    domain: Example.Accounts

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          email: String.t(),
          hashed_password: String.t(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  actions do
    defaults([:read])
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: true, sensitive?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  authentication do
    session_identifier(:jti)

    strategies do
      password do
        identity_field(:email)
        hashed_password_field(:hashed_password)
        registration_enabled? true
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
end
