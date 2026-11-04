# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule Dev.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Dev.PubSub},
      DevWeb.Endpoint,
      {AshAuthentication.Supervisor, otp_app: :ash_authentication_phoenix}
    ]

    opts = [strategy: :one_for_one, name: Dev.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      initialize_ets_resources()
      {:ok, pid}
    end
  end

  defp initialize_ets_resources do
    for resource <- [
          Example.Accounts.Admin,
          Example.Accounts.Token,
          Example.Accounts.User,
          Example.Accounts.WebAuthnCredential,
          Example.Accounts.AnonUser,
          Example.Accounts.AnonCredential
        ] do
      resource
      |> Ash.Query.for_read(:read)
      |> Ash.read!(domain: Example.Accounts)
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    DevWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
