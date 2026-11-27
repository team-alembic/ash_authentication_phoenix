# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Test.WebAuthnIdentityOverride do
  @moduledoc """
  Shows the optional identity input on the passkey sign-in form, whose value
  the strategy checks against the owner of the credential that signed.
  """
  use AshAuthentication.Phoenix.Overrides
  alias AshAuthentication.Phoenix.Components

  override Components.WebAuthn.AuthenticationForm do
    set :show_identity_field, true
  end
end
