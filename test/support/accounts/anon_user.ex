# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule Example.Accounts.AnonUser do
  @moduledoc false

  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication],
    domain: Example.Accounts

  alias Ash.Error.Changes.InvalidChanges
  alias Ash.Error.Query.InvalidArgument

  actions do
    defaults([:read, :create, :update])
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  # A request context saying `should_fail` refuses the register and sign-in
  # actions, as `Example.Accounts.User` refuses a password sign-in. That is
  # how the suite sees the request's context reach the strategy's actions,
  # which is what an invitation-only application relies on.
  changes do
    change(
      fn changeset, _ ->
        if changeset.action.name == :register_with_webauthn && changeset.context[:should_fail] do
          Ash.Changeset.add_error(
            changeset,
            InvalidChanges.exception(message: "I cant let you do that dave.")
          )
        else
          changeset
        end
      end,
      on: [:create]
    )
  end

  preparations do
    prepare fn query, _ ->
      if query.action.name == :sign_in_with_webauthn && query.context[:should_fail] do
        Ash.Query.add_error(
          query,
          InvalidArgument.exception(field: :raw_id, message: "I cant let you do that dave.")
        )
      else
        query
      end
    end
  end

  authentication do
    session_identifier(:jti)

    strategies do
      webauthn :webauthn do
        credential_resource Example.Accounts.AnonCredential
        require_identity? false
        # Resolves to "localhost" through a Secret, which lets the tests see
        # the context each ceremony hands the strategy. No `origin`: any
        # `http://localhost[:port]` is accepted under this `rp_id`, so neither
        # the dev server nor the tests need one.
        rp_id Example.Accounts.WebAuthnRelyingParty
        rp_name "AshAuthenticationPhoenix Dev (passkey-only)"
        # A machine with no authenticator of its own can still enrol and use a
        # passkey held on a phone, which is the point of passkey-only mode.
        # The QR scan, Bluetooth handshake and prompt on the second device
        # don't fit the default 60s timeout.
        hints [:hybrid, :security_key]
        timeout 300_000
        # Lets the components offer a secondary button that asks for the
        # other kind of authenticator — here "Use a passkey on this device",
        # since `:hybrid` leads — as `?hints=` does on the Plug endpoints.
        allow_hint_override? true
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
