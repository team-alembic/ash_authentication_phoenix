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
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    DevWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
