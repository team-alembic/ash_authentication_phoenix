# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Test.ResetButtonOverride do
  @moduledoc false
  use AshAuthentication.Phoenix.Overrides
  alias AshAuthentication.Phoenix.Components

  override Components.Reset.Form do
    set :button_text, "Set new password"
  end
end
