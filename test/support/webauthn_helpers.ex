# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Test.WebAuthnHelpers do
  @moduledoc """
  Test helpers for WebAuthn component tests.

  These helpers build a mock `AshAuthentication.Strategy.WebAuthn` struct used
  only for rendering tests (gated by the `:webauthn_strategy_required` tag).

  The mock uses `Example.Accounts.User` as its `:resource` because the component
  only needs the resource for subject-name derivation via `Info`. Actual WebAuthn
  ceremony tests (credential creation, sign-in) are not covered here — those
  belong in the upstream `ash_authentication` package alongside a dedicated
  fixture like `Example.UserWithWebAuthn`.
  """

  @doc """
  Returns a WebAuthn strategy struct for component testing.
  """
  def mock_webauthn_strategy(overrides \\ %{}) do
    defaults = %{
      name: :webauthn,
      resource: Example.Accounts.User,
      credential_resource: nil,
      rp_id: "localhost",
      rp_name: "Test App",
      identity_field: :email,
      authenticator_attachment: nil,
      user_verification: "preferred",
      attestation: "none",
      timeout: 60_000,
      resident_key: :required,
      registration_enabled?: true,
      register_action_name: :register_with_webauthn,
      sign_in_action_name: :sign_in_with_webauthn,
      credential_id_field: :credential_id,
      public_key_field: :public_key,
      sign_count_field: :sign_count,
      label_field: :label,
      last_used_at_field: :last_used_at,
      user_relationship_name: :user,
      credentials_relationship_name: :webauthn_credentials,
      store_credential_action_name: nil,
      update_sign_count_action_name: nil,
      list_credentials_action_name: :list_webauthn_credentials,
      delete_credential_action_name: :delete_webauthn_credential,
      update_credential_label_action_name: :update_webauthn_credential_label,
      add_credential_action_name: :add_webauthn_credential
    }

    merged = Map.merge(defaults, overrides)

    if Code.ensure_loaded?(AshAuthentication.Strategy.WebAuthn) do
      struct!(AshAuthentication.Strategy.WebAuthn, merged)
    else
      Map.put(merged, :__struct__, AshAuthentication.Strategy.WebAuthn)
    end
  end
end
