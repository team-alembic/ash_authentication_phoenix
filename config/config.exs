# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

import Config

if config_env() in [:dev, :test] do
  config :phoenix_live_view, :test_warnings, missing_form_id: :raise
end

import_config "#{config_env()}.exs"
