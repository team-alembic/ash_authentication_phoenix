# SPDX-FileCopyrightText: 2025 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

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

  `live_socket_id_template` is called here with the revoked token, and at sign-in
  with the token's claims. Both times the token's JWT ID is available as
  `&1["jti"]` and as `&1.jti`, so a template written either way produces the
  same socket ID in both places. Only revocations broadcast a disconnect;
  storing a token at sign-in or expunging expired tokens does not.

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
        action: %{type: type},
        data: %{purpose: "revocation", jti: jti} = data,
        resource: token_resource
      })
      when type in [:create, :update] do
    with {:ok, template_fn} <- Info.token_live_socket_id_template(token_resource),
         {:ok, endpoints} when endpoints != [] <- Info.token_endpoints(token_resource) do
      # The template also runs at sign-in in `set_live_socket_id/2`, where it gets
      # the token's claims with string keys. Put the JWT ID under both key styles
      # so a template written for either produces the same socket id in both places.
      socket_id =
        data
        |> Map.delete(:__struct__)
        |> Map.put("jti", jti)
        |> template_fn.()

      Enum.each(endpoints, fn endpoint ->
        endpoint.broadcast(socket_id, "disconnect", %{})
      end)
    end

    :ok
  end

  # Only revocations disconnect sessions. Storing a token at sign-in, expunging
  # expired tokens and writing other kinds of token are not revocations.
  def notify(_notification), do: :ok
end
