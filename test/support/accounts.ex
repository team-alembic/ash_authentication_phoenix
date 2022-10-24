defmodule Example.Accounts do
  use Ash.Api, otp_app: :ash_authentication_phoenix

  resources do
    registry Example.Accounts.Registry
  end
end
