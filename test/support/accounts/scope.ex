# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule Example.Accounts.Scope do
  @moduledoc false

  defstruct [:actor, :tenant]

  defimpl Ash.Scope.ToOpts, for: __MODULE__ do
    def get_actor(%{actor: actor}), do: {:ok, actor}
    def get_tenant(%{tenant: tenant}), do: {:ok, tenant}
    def get_context(_scope), do: :error
    def get_tracer(_scope), do: :error
    def get_authorize?(_scope), do: :error
  end
end
