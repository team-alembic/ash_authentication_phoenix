defmodule AshAuthentication.Phoenix.TokenRevocationNotifier do
  @moduledoc """
  An Ash notifier that broadcasts LiveView disconnect messages when tokens are revoked.

  When a user signs out, this notifier broadcasts a "disconnect" message to all
  configured Phoenix endpoints, causing any LiveView sessions using that token's
  JTI to be disconnected.

  ## Configuration

  To use this notifier, add it to your token resource and configure the required
  DSL options:

      defmodule MyApp.Accounts.Token do
        use Ash.Resource,
          extensions: [AshAuthentication.TokenResource],
          simple_notifiers: [AshAuthentication.Phoenix.TokenRevocationNotifier]

        token do
          endpoints [MyAppWeb.Endpoint]
          live_socket_id_template &("users_sessions:\#{&1["jti"]}")
        end
      end

  Then in your auth controller, call `set_live_socket_id/2` on sign-in to set
  the socket ID in the session:

      def success(conn, _activity, user, token) do
        conn
        |> store_in_session(user)
        |> set_live_socket_id(token)
        |> redirect(to: ~p"/")
      end
  """

  use Ash.Notifier
  alias AshAuthentication.TokenResource.Info

  @doc false
  @spec notify(Ash.Notifier.Notification.t()) :: :ok
  def notify(%Ash.Notifier.Notification{
        data: %{subject: "user"}
      }),
      do: :ok

  def notify(%Ash.Notifier.Notification{
        data: data,
        resource: token_resource
      }) do
    with {:ok, template_fn} <- Info.token_live_socket_id_template(token_resource),
         socket_id <- template_fn.(data),
         {:ok, endpoints} when endpoints != [] <- Info.token_endpoints(token_resource) do
      Enum.each(endpoints, fn endpoint ->
        endpoint.broadcast(socket_id, "disconnect", %{})
      end)
    end

    :ok
  end
end
