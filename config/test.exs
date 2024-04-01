import Config

config :bcrypt_elixir, :log_rounds, 4

config :ash, :disable_async?, true

config :ash_authentication_phoenix, ash_domains: [Example.Accounts]

config :ash_authentication_phoenix, AshAuthentication.JsonWebToken,
  signing_secret: "All I wanna do is to thank you, even though I don't know who you are."

config :ash_authentication, AshAuthentication.Jwt,
  signing_secret: "Marty McFly in the past with the Delorean"

config :phoenix, :json_library, Jason
