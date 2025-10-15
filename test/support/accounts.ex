# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule Example.Accounts do
  @moduledoc false
  use Ash.Domain, otp_app: :ash_authentication_phoenix

  resources do
    resource Example.Accounts.Admin
    resource Example.Accounts.Token
    resource Example.Accounts.User
  end
end
