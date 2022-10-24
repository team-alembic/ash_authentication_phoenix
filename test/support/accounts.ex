defmodule Example.Accounts do
  @moduledoc false
  use Ash.Api, otp_app: :ash_authentication_phoenix

  resources do
    registry Example.Accounts.Registry
  end
end
