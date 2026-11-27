# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Test.WebAuthnPanelOverride do
  @moduledoc """
  Sets every text, class and callable the passkey management panel exposes
  to a value the tests can look for, the way an application translating
  and styling the panel would.
  """
  use AshAuthentication.Phoenix.Overrides
  alias AshAuthentication.Phoenix.Components

  override Components.WebAuthn.ManageCredentials do
    set :error_class, "panel-error"
    set :rename_form_class, "panel-rename-form"
    set :save_button_class, "panel-save"
    set :cancel_button_class, "panel-cancel"
    set :credential_details_class, "panel-details"
    set :credential_actions_class, "panel-actions"
    set :label_class, "panel-label"
    set :empty_state_class, "panel-empty"
    set :default_label_text, "Nyckel"
    set :added_text, "Registrerad"
    set :last_used_text, "Senast använd"
    set :timestamp_separator_text, "·"
    set :format_timestamp, &__MODULE__.stamp/2
  end

  @doc "A formatter whose output says which timestamp it was given."
  @spec stamp(DateTime.t(), :added | :last_used) :: String.t()
  def stamp(at, kind), do: "#{kind}@#{DateTime.to_iso8601(at)}"
end
