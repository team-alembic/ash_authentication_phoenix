defmodule Example.Accounts.User do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [
      AshAuthentication,
      AshAuthentication.Confirmation,
      AshAuthentication.PasswordAuthentication,
      AshAuthentication.PasswordReset,
      AshAuthentication.OAuth2Authentication
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

  oauth2_authentication do
    provider_name(:auth0)
    client_id(&get_config/3)
    redirect_uri(&get_config/3)
    client_secret(&get_config/3)
    site(&get_config/3)

    authorize_path("/authorize")
    token_path("/oauth/token")
    user_path("/userinfo")
    authorization_params(scope: "openid profile email")
    auth_method(:client_secret_post)
  end

  tokens do
    enabled?(true)
    revocation_resource(Example.Accounts.TokenRevocation)
  end

  identities do
    identity(:unique_email, [:email], pre_check_with: Example.Accounts)
  end

  def get_config(path, resource, _opts) do
    value =
      :ash_authentication_phoenix
      |> Application.get_env(resource, [])
      |> get_in(path)

    {:ok, value}
  end
end
