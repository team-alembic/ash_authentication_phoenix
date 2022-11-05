defmodule Example.Accounts.User do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [
      AshAuthentication,
      AshAuthentication.Confirmation,
      AshAuthentication.PasswordAuthentication,
      AshAuthentication.PasswordReset,
      AshAuthentication.FacebookAuthentication
    ]

  require Logger

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          email: String.t(),
          hashed_password: String.t(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  actions do
    defaults([:read])
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:email, :ci_string, allow_nil?: false)
    attribute(:hashed_password, :string, allow_nil?: false, sensitive?: true, private?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  authentication do
    api(Example.Accounts)
  end

  confirmation do
    monitor_fields([:email])

    sender(fn user, token ->
      Logger.debug("Confirmation request for #{user.email} with token #{inspect(token)}")
    end)
  end

  password_authentication do
    identity_field(:email)
    hashed_password_field(:hashed_password)
  end

  password_reset do
    sender(fn user, token ->
      Logger.debug("Password reset request for #{user.email} with token #{inspect(token)}")
    end)
  end

  tokens do
    enabled?(true)
    revocation_resource(Example.Accounts.TokenRevocation)
  end

  identities do
    identity(:email, [:email], pre_check_with: Example.Accounts)
  end
end
