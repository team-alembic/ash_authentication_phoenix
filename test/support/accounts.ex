defmodule Example.Accounts do
  @moduledoc false
  use Ash.Api, otp_app: :ash_authentication_phoenix

  resources do
    resource Example.Accounts.User
    resource Example.Accounts.Token
  end
end
