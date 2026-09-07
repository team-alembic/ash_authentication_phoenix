# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

import Config

import_config "#{config_env()}.exs"

config :ash, default_string_length_count: :codepoints
