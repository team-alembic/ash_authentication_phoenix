# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule DevWeb.AuthOverrides do
  @moduledoc false
  use AshAuthentication.Phoenix.Overrides
  alias AshAuthentication.Phoenix.Components

  override Components.Banner do
    set :image_url, "https://media.giphy.com/media/g7GKcSzwQfugw/giphy.gif"
  end

  override Components.Password.Input do
    set :password_toggle_visibility, true
  end
end
