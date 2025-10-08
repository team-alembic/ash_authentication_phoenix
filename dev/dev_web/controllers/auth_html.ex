# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule RamblerWeb.AuthHTML do
  @moduledoc """
  This module contains pages rendered by AuthController.

  See the `auth_html` directory for all templates available.
  """
  use DevWeb, :html

  embed_templates "auth_html/*"
end
