# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.TokenRevocationNotifierTest do
  @moduledoc false
  use AshAuthentication.Phoenix.Test.ConnCase
  use Mimic

  alias AshAuthentication.{Jwt, TokenResource}
  alias AshAuthentication.Phoenix.{Controller, TokenRevocationNotifier}
  alias AshAuthentication.Phoenix.Test.Endpoint
  alias Example.Accounts.{Token, User}
  alias Phoenix.Socket.Broadcast

  setup %{conn: conn} do
    user =
      User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "notifier-#{System.unique_integer([:positive])}@example.com",
        password: "secure-password",
        password_confirmation: "secure-password"
      })
      |> Ash.create!()

    token = user.__metadata__.token
    {:ok, %{"jti" => jti}} = Jwt.peek(token)

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> put_private(:phoenix_endpoint, Endpoint)

    %{conn: conn, token: token, jti: jti}
  end

  describe "signing out disconnects the session's LiveViews" do
    # The test token resource uses the template `mix ash_authentication_phoenix.install` writes.
    test "with a template reading the string key", %{conn: conn, token: token, jti: jti} do
      assert_revocation_disconnects(conn, token, jti)
    end

    test "with a template reading the atom key", %{conn: conn, token: token, jti: jti} do
      stub(TokenResource.Info, :token_live_socket_id_template, fn _ ->
        {:ok, fn %{jti: jti} -> "users_sessions:#{jti}" end}
      end)

      assert_revocation_disconnects(conn, token, jti)
    end
  end

  describe "writes that are not revocations" do
    setup %{jti: jti} do
      topic = "users_sessions:#{jti}"
      Endpoint.subscribe(topic)
      %{topic: topic}
    end

    test "storing a token does not disconnect", %{jti: jti, topic: topic} do
      notify(:store_token, %Token{jti: jti, purpose: "user"})

      refute_receive %Broadcast{topic: ^topic}
    end

    test "expunging an expired revocation does not disconnect", %{jti: jti, topic: topic} do
      notify(:expunge_expired, %Token{jti: jti, purpose: "revocation"})

      refute_receive %Broadcast{topic: ^topic}
    end
  end

  defp assert_revocation_disconnects(conn, token, jti) do
    topic = "users_sessions:#{jti}"

    conn = Controller.set_live_socket_id(conn, token)
    assert get_session(conn, :live_socket_id) == topic

    Endpoint.subscribe(topic)
    assert :ok = TokenResource.revoke(Token, token)

    assert_receive %Broadcast{topic: ^topic, event: "disconnect"}
  end

  defp notify(action_name, data) do
    TokenRevocationNotifier.notify(%Ash.Notifier.Notification{
      resource: Token,
      action: Ash.Resource.Info.action(Token, action_name),
      data: data
    })
  end
end
