import Config

config :git_ops,
  mix_project: Mix.Project.get!(),
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/team-alembic/ash_authentication_phoenix",
  manage_mix_version?: true,
  manage_readme_version: [
    "README.md",
    "documentation/tutorials/getting-started-with-ash-authentication-phoenix.md"
  ],
  version_tag_prefix: "v"

config :ash_authentication_phoenix, DevWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: DevWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Dev.PubSub,
  live_view: [signing_salt: "mwTS8kFY"],
  http: [ip: {127, 0, 0, 1}, port: 4000],
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
        redirect_uri: "http://localhost:4000/auth",
        site: System.get_env("OAUTH2_SITE")
      ],
      github: [
        client_id: System.get_env("GITHUB_CLIENT_ID"),
        client_secret: System.get_env("GITHUB_CLIENT_SECRET"),
        redirect_uri: "http://localhost:4000/auth"
      ]
    ]
  ]
