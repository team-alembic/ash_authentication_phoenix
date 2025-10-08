# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

import Config

config :bcrypt_elixir, :log_rounds, 4

config :ash, :disable_async?, true

config :ash_authentication_phoenix, ash_domains: [Example.Accounts]

config :ash_authentication_phoenix,
  signing_secret: "Marty McFly in the past with the Delorean"

config :phoenix, :json_library, Jason

config :ash_authentication_phoenix, AshAuthentication.Phoenix.Test.Endpoint,
  server: false,
  debug_errors: true,
  live_view: [signing_salt: "aaaaaaaa"],
  secret_key_base: String.duplicate("a", 64)

config :logger, level: :error
