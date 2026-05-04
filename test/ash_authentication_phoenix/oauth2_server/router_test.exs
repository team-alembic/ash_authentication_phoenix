# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Oauth2Server.RouterTest do
  @moduledoc """
  HTTP-level test for the Oauth2Server routers, driven through Plug.Test.

  Protocol-level correctness (PKCE, JWT claims, code consume, etc.) is
  covered in the `ash_authentication` core tests. This file only validates
  the HTTP surface — status codes, headers, JSON shapes, redirects, route
  splitting between ConsentRouter and ProtocolRouter.
  """
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias AshAuthentication.Oauth2Server.PKCE

  alias AshAuthentication.Phoenix.Oauth2Server.{ConsentRouter, ProtocolRouter}
  alias Oauth2ServerTest.Server

  alias Oauth2ServerTest.{
    OAuthAuthorizationCode,
    OAuthClient,
    OAuthConsent,
    OAuthRefreshToken,
    User
  }

  @consent_opts ConsentRouter.init(oauth2_server: Server)
  @protocol_opts ProtocolRouter.init(oauth2_server: Server)

  setup do
    for resource <- [OAuthClient, OAuthAuthorizationCode, OAuthRefreshToken, OAuthConsent, User] do
      Ash.bulk_destroy!(resource, :destroy, %{}, return_errors?: true)
    end

    user =
      User
      |> Ash.Changeset.for_create(:create, %{email: "alice@example.com"})
      |> Ash.create!()

    {:ok, user: user}
  end

  defp call_consent(conn), do: ConsentRouter.call(conn, @consent_opts)
  defp call_protocol(conn), do: ProtocolRouter.call(conn, @protocol_opts)

  defp register_client(redirect_uri \\ "https://chat.example.com/cb") do
    conn(:post, "/register", Jason.encode!(%{
      "client_name" => "Test",
      "redirect_uris" => [redirect_uri]
    }))
    |> put_req_header("content-type", "application/json")
    |> call_protocol()
  end

  defp pkce do
    verifier = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    {verifier, PKCE.challenge(verifier)}
  end

  describe "ProtocolRouter: GET /oauth-authorization-server" do
    test "returns RFC 8414 metadata as JSON" do
      conn = call_protocol(conn(:get, "/oauth-authorization-server"))

      assert conn.status == 200
      assert ["application/json"] = get_resp_header(conn, "content-type")
      body = Jason.decode!(conn.resp_body)
      assert body["issuer"] == Server.issuer_url()
      assert body["token_endpoint"] =~ "/oauth/token"
      assert "S256" in body["code_challenge_methods_supported"]
    end
  end

  describe "ProtocolRouter: GET /openid-configuration (alias)" do
    test "returns the same body as oauth-authorization-server" do
      a = call_protocol(conn(:get, "/oauth-authorization-server")) |> Map.get(:resp_body)
      b = call_protocol(conn(:get, "/openid-configuration")) |> Map.get(:resp_body)
      assert a == b
    end
  end

  describe "ProtocolRouter: GET /oauth-protected-resource" do
    test "returns RFC 9728 metadata as JSON" do
      conn = call_protocol(conn(:get, "/oauth-protected-resource"))

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["resource"] == Server.resource_url()
      assert body["authorization_servers"] == [Server.issuer_url()]
    end
  end

  describe "ProtocolRouter: POST /register" do
    test "registers a client and returns 201 + RFC 7591 body" do
      conn = register_client()

      assert conn.status == 201
      body = Jason.decode!(conn.resp_body)
      assert is_binary(body["client_id"])
      assert body["redirect_uris"] == ["https://chat.example.com/cb"]
      assert body["scope"] == "mcp"
    end

    test "rejects bogus redirect_uris with 400 + invalid_redirect_uri" do
      conn =
        conn(:post, "/register",
          Jason.encode!(%{"redirect_uris" => ["http://evil.example.com/cb"]})
        )
        |> put_req_header("content-type", "application/json")
        |> call_protocol()

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "invalid_redirect_uri"
    end
  end

  describe "ConsentRouter: GET /authorize" do
    test "401s when no actor is present and no sign_in_path is configured" do
      {client_id, redirect_uri} = create_client_for_authorize()
      {_v, challenge} = pkce()

      conn =
        conn(:get, "/?" <> URI.encode_query(authorize_query(client_id, redirect_uri, challenge)))
        |> call_consent()

      assert conn.status == 401
    end

    test "302s with code when consent already exists", %{user: user} do
      {client_id, redirect_uri} = create_client_for_authorize()
      {_v, challenge} = pkce()

      OAuthConsent
      |> Ash.Changeset.for_create(:grant, %{user_id: user.id, client_id: client_id, scope: "mcp"})
      |> Ash.create!()

      conn =
        conn(:get, "/?" <> URI.encode_query(authorize_query(client_id, redirect_uri, challenge)))
        |> Ash.PlugHelpers.set_actor(user)
        |> call_consent()

      assert conn.status == 302
      [location] = get_resp_header(conn, "location")
      assert String.starts_with?(location, redirect_uri <> "?")
      query = location |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
      assert is_binary(query["code"])
      assert query["state"] == "csrf-state"
    end

    test "renders consent HTML when no prior consent and user is logged in", %{user: user} do
      {client_id, redirect_uri} = create_client_for_authorize()
      {_v, challenge} = pkce()

      conn =
        conn(:get, "/?" <> URI.encode_query(authorize_query(client_id, redirect_uri, challenge)))
        |> Ash.PlugHelpers.set_actor(user)
        |> call_consent()

      assert conn.status == 200
      assert ["text/html; charset=utf-8"] = get_resp_header(conn, "content-type")
      assert conn.resp_body =~ "Authorize"
      assert conn.resp_body =~ "Approve"
    end
  end

  describe "ConsentRouter: POST /authorize" do
    test "approves and 302s with code, recording consent", %{user: user} do
      {client_id, redirect_uri} = create_client_for_authorize()
      {_v, challenge} = pkce()

      params =
        authorize_query(client_id, redirect_uri, challenge)
        |> Map.put("action", "approve")

      conn =
        conn(:post, "/", params)
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> Ash.PlugHelpers.set_actor(user)
        |> call_consent()

      assert conn.status == 302
      [location] = get_resp_header(conn, "location")
      assert String.starts_with?(location, redirect_uri <> "?")

      assert {:ok, [_]} = Ash.read(OAuthConsent)
    end

    test "deny redirects with error=access_denied", %{user: user} do
      {client_id, redirect_uri} = create_client_for_authorize()
      {_v, challenge} = pkce()

      params =
        authorize_query(client_id, redirect_uri, challenge)
        |> Map.put("action", "deny")

      conn =
        conn(:post, "/", params)
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> Ash.PlugHelpers.set_actor(user)
        |> call_consent()

      assert conn.status == 302
      [location] = get_resp_header(conn, "location")
      query = location |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
      assert query["error"] == "access_denied"
    end
  end

  describe "ProtocolRouter: POST /token (authorization_code grant)" do
    test "exchanges code for tokens with valid PKCE", %{user: user} do
      {client_id, redirect_uri} = create_client_for_authorize()
      {verifier, challenge} = pkce()

      params = authorize_query(client_id, redirect_uri, challenge) |> Map.put("action", "approve")

      authorize_conn =
        conn(:post, "/", params)
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> Ash.PlugHelpers.set_actor(user)
        |> call_consent()

      [location] = get_resp_header(authorize_conn, "location")
      query = location |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
      code = query["code"]

      token_conn =
        conn(:post, "/token", %{
          "grant_type" => "authorization_code",
          "code" => code,
          "redirect_uri" => redirect_uri,
          "code_verifier" => verifier,
          "client_id" => client_id,
          "resource" => Server.resource_url()
        })
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> call_protocol()

      assert token_conn.status == 200
      body = Jason.decode!(token_conn.resp_body)
      assert body["token_type"] == "Bearer"
      assert is_binary(body["access_token"])
      assert is_binary(body["refresh_token"])
      assert body["scope"] == "mcp"
      assert body["expires_in"] == Server.access_token_lifetime()

      assert {:ok, claims} =
               AshAuthentication.Oauth2Server.Jwt.verify(Server, body["access_token"])

      assert claims["sub"] == user.id
    end

    test "unsupported grant_type returns 400 + RFC code" do
      conn =
        conn(:post, "/token", %{"grant_type" => "password"})
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> call_protocol()

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "unsupported_grant_type"
    end
  end

  describe "router scoping" do
    test "ConsentRouter only handles / (the /oauth/authorize prefix is stripped)" do
      assert call_consent(conn(:post, "/token")).status == 404
      assert call_consent(conn(:get, "/oauth-authorization-server")).status == 404
    end

    test "ProtocolRouter doesn't accidentally handle / (consent's path)" do
      assert call_protocol(conn(:get, "/")).status == 404
    end
  end

  # ── helpers ────────────────────────────────────────────────────────────────

  defp create_client_for_authorize do
    conn = register_client("https://chat.example.com/cb")
    body = Jason.decode!(conn.resp_body)
    {body["client_id"], "https://chat.example.com/cb"}
  end

  defp authorize_query(client_id, redirect_uri, challenge) do
    %{
      "response_type" => "code",
      "client_id" => client_id,
      "redirect_uri" => redirect_uri,
      "code_challenge" => challenge,
      "code_challenge_method" => "S256",
      "scope" => "mcp",
      "state" => "csrf-state",
      "resource" => Server.resource_url()
    }
  end
end
