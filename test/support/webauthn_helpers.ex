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
      adapter: AshAuthentication.Strategy.WebAuthn.Adapters.Wax,
      resource: Example.Accounts.User,
      credential_resource: Example.Accounts.WebAuthnCredential,
      rp_id: "localhost",
      rp_name: "Test App",
      require_identity?: nil,
      identity_field: :email,
      authenticator_attachment: nil,
      hints: [],
      allow_hint_override?: false,
      user_verification: "preferred",
      attestation: "none",
      trusted_attestation_types: [:none, :basic, :self, :uncertain],
      verify_trust_root?: false,
      timeout: 60_000,
      resident_key: :required,
      sign_count_policy: :reject,
      credentials_relationship_name: :webauthn_credentials,
      registration_enabled?: true,
      sign_in_enabled?: true,
      verify_enabled?: true,
      register_action_name: :register_with_webauthn,
      sign_in_action_name: :sign_in_with_webauthn
    }

    # `struct!/2` deliberately: a key that has moved off the struct — as the
    # credential field and action names did when they became part of the
    # `AshAuthentication.WebAuthnCredential` resource extension — should fail
    # loudly here rather than leave the mock quietly out of shape.
    struct!(AshAuthentication.Strategy.WebAuthn, Map.merge(defaults, overrides))
  end
end
