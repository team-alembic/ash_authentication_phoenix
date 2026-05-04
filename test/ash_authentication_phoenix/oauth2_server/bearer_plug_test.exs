# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Oauth2Server.BearerPlugTest do
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias AshAuthentication.Oauth2Server.Jwt
  alias AshAuthentication.Phoenix.Oauth2Server.BearerPlug
  alias Oauth2ServerTest.Server
  alias Oauth2ServerTest.User

  @opts BearerPlug.init(oauth2_server: Server)

  setup do
    Ash.bulk_destroy!(User, :destroy, %{}, return_errors?: true)

    user =
      User
      |> Ash.Changeset.for_create(:create, %{email: "alice@example.com"})
      |> Ash.create!()

    {:ok, user: user}
  end

  test "401 with WWW-Authenticate when no token is present" do
    conn = BearerPlug.call(conn(:get, "/protected"), @opts)

    assert conn.status == 401
    [www_auth] = get_resp_header(conn, "www-authenticate")
    assert www_auth =~ "Bearer resource_metadata="
    assert www_auth =~ Server.resource_url()
  end

  test "valid token sets the actor and assigns claims", %{user: user} do
    {:ok, token, _claims} =
      Jwt.mint(Server, sub: user.id, client_id: "some-client", scope: "mcp")

    conn =
      conn(:get, "/protected")
      |> put_req_header("authorization", "Bearer " <> token)
      |> BearerPlug.call(@opts)

    refute conn.halted
    assert Ash.PlugHelpers.get_actor(conn).id == user.id
    assert conn.assigns.oauth_claims["client_id"] == "some-client"
    assert conn.assigns.oauth_claims["scope"] == "mcp"
  end

  test "tampered token returns 401 + invalid_token error" do
    conn =
      conn(:get, "/protected")
      |> put_req_header("authorization", "Bearer not.a.valid.jwt")
      |> BearerPlug.call(@opts)

    assert conn.status == 401
    [www_auth] = get_resp_header(conn, "www-authenticate")
    assert www_auth =~ "error=\"invalid_token\""
  end

  test "audience-mismatched token returns 401 + audience mismatch description", %{user: user} do
    # Mint a token with the correct secret but a wrong audience
    claims = %{
      "iss" => Server.issuer_url(),
      "sub" => user.id,
      "aud" => "https://attacker.example.com",
      "exp" => System.system_time(:second) + 60
    }

    signer = Joken.Signer.create("HS256", Server.signing_secret())
    {:ok, bad_token, _} = Joken.encode_and_sign(claims, signer)

    conn =
      conn(:get, "/protected")
      |> put_req_header("authorization", "Bearer " <> bad_token)
      |> BearerPlug.call(@opts)

    assert conn.status == 401
    [www_auth] = get_resp_header(conn, "www-authenticate")
    assert www_auth =~ "audience mismatch"
  end

  test "with required?: false, missing token passes through unchanged" do
    opts = BearerPlug.init(oauth2_server: Server, required?: false)
    conn = BearerPlug.call(conn(:get, "/protected"), opts)

    refute conn.halted
    assert conn.status == nil
    assert Ash.PlugHelpers.get_actor(conn) == nil
  end
end
