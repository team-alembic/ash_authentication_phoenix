defmodule Example.Accounts.User do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [
      AshAuthentication,
      AshAuthentication.Confirmation,
      AshAuthentication.PasswordAuthentication,
      AshAuthentication.PasswordReset
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

    create :register_with_auth0 do
      argument :user_info, :map, allow_nil?: false
      argument :oauth_tokens, :map, allow_nil?: false
      upsert? true
      upsert_identity :unique_email

      change AshAuthentication.GenerateTokenChange

      change fn changeset, _ ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)

        changeset
        |> Ash.Changeset.change_attribute(:email, user_info["email"])
      end
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:email, :ci_string, allow_nil?: false)
    attribute(:hashed_password, :string, allow_nil?: true, sensitive?: true, private?: true)

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
    identity(:unique_email, [:email], pre_check_with: Example.Accounts)
  end
end
