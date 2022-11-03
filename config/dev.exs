import Config

config :git_ops,
  mix_project: Mix.Project.get!(),
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/team-alembic/ash_authentication_phoenix",
  manage_mix_version?: true,
  manage_readme_version: "README.md",
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

config :ash_authentication_phoenix, ash_apis: [Example.Accounts], namespace: Dev

config :ash_authentication, AshAuthentication.Jwt,
  signing_secret: "All I wanna do is to thank you, even though I don't know who you are."

config :phoenix, :json_library, Jason
