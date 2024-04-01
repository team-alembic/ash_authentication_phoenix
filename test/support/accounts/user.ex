defmodule Example.Accounts.User do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication],
    domain: Example.Accounts

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

    create :register_with_github do
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
    uuid_primary_key :id

    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: true, sensitive?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  authentication do
    add_ons do
      confirmation :confirm do
        monitor_fields([:email])

        sender(fn user, token, _ ->
          Logger.debug("Confirmation request for #{user.email} with token #{inspect(token)}")
        end)
      end
    end

    strategies do
      password do
        identity_field(:email)
        hashed_password_field(:hashed_password)
        registration_enabled? true
        sign_in_tokens_enabled? true

        resettable do
          sender(fn user, token, _ ->
            Logger.debug("Password reset request for #{user.email} with token #{inspect(token)}")
          end)
        end
      end

      auth0 do
        client_id(&get_config/2)
        redirect_uri(&get_config/2)
        client_secret(&get_config/2)
        base_url(&get_config/2)
      end

      github do
        client_id &get_config/2
        redirect_uri &get_config/2
        client_secret &get_config/2
      end

      magic_link do
        identity_field :email

        sender(fn user, token, _ ->
          Logger.debug("Magic link request for #{user.email} with token #{inspect(token)}")
        end)
      end
    end

    tokens do
      enabled?(true)
      token_resource(Example.Accounts.Token)

      signing_secret(fn _, _ ->
        Application.fetch_env(:ash_authentication_phoenix, :signing_secret)
      end)
    end
  end

  identities do
    identity(:unique_email, [:email],
      pre_check_with: Example.Accounts,
      eager_check_with: Example.Accounts
    )
  end

  def get_config(path, resource) do
    value =
      :ash_authentication_phoenix
      |> Application.get_env(resource, [])
      |> get_in(path)

    {:ok, value}
  end
end
