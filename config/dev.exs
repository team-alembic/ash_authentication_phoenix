# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

import Config

config :git_ops,
  mix_project: Mix.Project.get!(),
  github_handle_lookup?: true,
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/team-alembic/ash_authentication_phoenix",
  manage_mix_version?: true,
  manage_readme_version: [
    "README.md",
    "documentation/tutorials/get-started.md"
  ],
  version_tag_prefix: "v"

ip =
  with ip when is_binary(ip) <- System.get_env("IP"),
       {:ok, ip} <-
         ip
         |> String.to_charlist()
         |> :inet.parse_address() do
    ip
  else
    _ -> {127, 0, 0, 1}
  end

port =
  System.get_env("PORT", "4000")
  |> String.to_integer()

tls_port =
  System.get_env("TLS_PORT", "4001")
  |> String.to_integer()

host =
  System.get_env("HOST", "localhost")

config :ash_authentication_phoenix, DevWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: host, port: port],
  render_errors: [view: DevWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Dev.PubSub,
  live_view: [signing_salt: "mwTS8kFY"],
  http: [ip: ip, port: port],
  https: [
    port: tls_port,
    cipher_suite: :strong,
    certfile: "priv/cert/selfsigned.pem",
    keyfile: "priv/cert/selfsigned_key.pem"
  ],
  check_origin: false,
  debug_errors: true,
  secret_key_base: "5PmCh9zQTJuCjlXm2EeF+hoYLkFxgH/3bzLE8D0Tzg5XLw6ZIMGipHFbr0z19dlC",
  server: true

config :ash_authentication_phoenix, ash_domains: [Example.Accounts], namespace: Dev

config :ash_authentication_phoenix,
  signing_secret: "All I wanna do is to thank you, even though I don't know who you are."

config :phoenix, :json_library, Jason

config :ash_authentication_phoenix, Example.Accounts.User,
  authentication: [
    strategies: [
      auth0: [
        client_id: System.get_env("OAUTH2_CLIENT_ID"),
        client_secret: System.get_env("OAUTH2_CLIENT_SECRET"),
        redirect_uri: "http://localhost:#{port}/auth",
        site: System.get_env("OAUTH2_SITE")
      ],
      github: [
        client_id: System.get_env("GITHUB_CLIENT_ID"),
        client_secret: System.get_env("GITHUB_CLIENT_SECRET"),
        redirect_uri: "http://localhost:#{port}/auth"
      ]
    ]
  ]
