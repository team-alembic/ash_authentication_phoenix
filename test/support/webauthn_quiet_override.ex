# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Test.WebAuthnQuietOverride do
  @moduledoc """
  Drops every optional text on the WebAuthn forms: the description under
  each heading and the links between the two forms. An explicit `nil` wins
  over the default overrides listed after this module.
  """
  use AshAuthentication.Phoenix.Overrides
  alias AshAuthentication.Phoenix.Components

  override Components.WebAuthn do
    set :register_link_text, nil
    set :sign_in_link_text, nil
  end

  override Components.WebAuthn.AuthenticationForm do
    set :description_text, nil
  end

  override Components.WebAuthn.RegistrationForm do
    set :description_text, nil
  end
end
