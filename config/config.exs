import Config

# Necessary to remove warning from core when developing/testing
config :ash, :use_all_identities_in_manage_relationship?, false

import_config "#{config_env()}.exs"
