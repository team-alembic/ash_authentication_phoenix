# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Test.WebAuthnFixtures do
  @moduledoc """
  Plays the authenticator in WebAuthn component tests.

  A passkey here is a real EC P-256 key pair, so the attestation and
  assertion it produces verify through the strategy's default adapter like
  a browser's would, with no mocking of the ceremony. Each helper takes the
  challenge the strategy itself issued — either the term
  `Actions.registration_challenge/3` returns, or the base64url string a
  LiveView pushed to the client — and answers it the way
  `navigator.credentials.create()` / `.get()` and the JS hooks would.

  The relying party ID and the origin are read from the strategy, so the
  fixtures hold for whatever `rp_id` the test resources configure.
  """

  alias AshAuthentication.Strategy.WebAuthn.{Actions, Helpers}

  @typedoc "A registered passkey: the key pair plus what the strategy stored."
  @type passkey :: %{
          credential_id: binary,
          cose_key: map,
          private_key: tuple,
          user_handle: binary | nil,
          attestation_object: String.t(),
          client_data_json: String.t(),
          raw_id: String.t()
        }

  @doc """
  The `{rp_id, origin}` a browser would present for `strategy` in `tenant`.

  With no `origin` configured, the strategy accepts any `https` origin on
  the `rp_id` and `http://localhost` on any port when the `rp_id` is
  `localhost`, so a plausible one is derived.
  """
  @spec relying_party(struct, any) :: {String.t(), String.t()}
  def relying_party(strategy, tenant \\ nil) do
    rp_id = Helpers.resolve_rp_id(strategy, tenant)

    origin =
      case Helpers.resolve_origin(strategy, tenant) do
        nil when rp_id == "localhost" -> "http://localhost:4002"
        nil -> "https://" <> rp_id
        [origin | _] -> origin
        origin -> origin
      end

    {rp_id, origin}
  end

  @doc """
  Register a new user through the strategy with a freshly minted passkey.

  `params` are the register action's own inputs (the identity, custom
  fields). The server-side user handle is random, as the components mint
  it, unless `:user_handle` is given. Returns the action's result and the
  passkey, which carries the handle so later assertions can return it.
  """
  @spec register(struct, map, keyword) :: {{:ok, struct} | {:error, any}, passkey}
  def register(strategy, params \\ %{}, opts \\ []) do
    tenant = opts[:tenant]
    {:ok, challenge} = Actions.registration_challenge(strategy, tenant)
    passkey = new_passkey(strategy, challenge, tenant)

    user_handle =
      Keyword.get_lazy(opts, :user_handle, fn -> :crypto.strong_rand_bytes(32) end)

    result =
      Actions.register(strategy, Map.merge(registration_params(passkey), params),
        challenge: challenge,
        tenant: tenant,
        user_handle: user_handle
      )

    {result, %{passkey | user_handle: user_handle}}
  end

  @doc """
  A new passkey answering `challenge` (the strategy's challenge term) for
  `strategy`'s relying party.
  """
  @spec new_passkey(struct, term, any) :: passkey
  def new_passkey(strategy, challenge, tenant \\ nil) do
    {rp_id, origin} = relying_party(strategy, tenant)

    generate_registration(
      origin: origin,
      rp_id: rp_id,
      challenge_bytes: strategy.adapter.challenge_bytes(challenge)
    )
  end

  @doc """
  The params the `WebAuthnRegistrationHook` pushes back after creating a
  credential for the creation options a LiveView pushed.

  `encoded_challenge` is the base64url challenge from those options.
  """
  @spec attestation_event(struct, String.t(), keyword) :: {map, passkey}
  def attestation_event(strategy, encoded_challenge, opts \\ []) do
    {rp_id, origin} = relying_party(strategy, opts[:tenant])

    passkey =
      generate_registration(
        origin: origin,
        rp_id: rp_id,
        challenge_bytes: Base.url_decode64!(encoded_challenge, padding: false)
      )

    event =
      passkey
      |> registration_params()
      |> Map.merge(%{
        "transports" => Keyword.get(opts, :transports, ["internal"]),
        "cred_props" => %{"rk" => true}
      })

    {event, passkey}
  end

  @doc """
  The params the `WebAuthnAuthenticationHook` pushes back after signing
  the request options a LiveView pushed.

  `encoded_challenge` is the base64url challenge from those options. The
  assertion returns the passkey's own user handle unless `:user_handle`
  names another (or `nil`, for an authenticator that returns none).
  """
  @spec assertion_event(struct, passkey, String.t(), keyword) :: map
  def assertion_event(strategy, passkey, encoded_challenge, opts \\ []) do
    {rp_id, origin} = relying_party(strategy, opts[:tenant])

    assertion =
      generate_authentication(passkey,
        challenge_bytes: Base.url_decode64!(encoded_challenge, padding: false),
        rp_id: rp_id,
        origin: origin,
        # Strictly increasing across the suite, so no assertion trips the
        # strategy's clone detection.
        sign_count: System.unique_integer([:positive, :monotonic])
      )

    user_handle = Keyword.get(opts, :user_handle, passkey.user_handle)

    %{
      "raw_id" => url64(assertion.raw_id),
      "authenticator_data" => assertion.authenticator_data,
      "signature" => assertion.signature,
      "client_data_json" => assertion.client_data_json,
      "user_handle" => user_handle && url64(user_handle)
    }
  end

  defp registration_params(passkey) do
    %{
      "attestation_object" => passkey.attestation_object,
      "client_data_json" => passkey.client_data_json,
      "raw_id" => passkey.raw_id
    }
  end

  @doc """
  A complete registration: a fresh EC P-256 key pair and the `"none"`
  attestation a browser would return for it.

  Options: `:origin`, `:rp_id`, `:challenge_bytes` (random when absent),
  `:credential_id`, `:flags` (authenticator data flags byte, `0x41`: UP + AT).
  """
  @spec generate_registration(keyword) :: passkey
  def generate_registration(opts \\ []) do
    origin = Keyword.fetch!(opts, :origin)
    rp_id = Keyword.fetch!(opts, :rp_id)

    # OTP 27 returns the ECPrivateKey record as a 6-tuple with the public
    # point at index 4, as an uncompressed SEC1 point: 0x04 || x || y.
    private_key = :public_key.generate_key({:namedCurve, :secp256r1})
    <<4, x::binary-size(32), y::binary-size(32)>> = elem(private_key, 4)

    # COSE EC2 key: kty 2, alg -7 (ES256), crv 1 (P-256), x, y.
    cose_key = %{1 => 2, 3 => -7, -1 => 1, -2 => x, -3 => y}

    credential_id =
      Keyword.get_lazy(opts, :credential_id, fn -> :crypto.strong_rand_bytes(32) end)

    challenge_bytes =
      Keyword.get_lazy(opts, :challenge_bytes, fn -> :crypto.strong_rand_bytes(32) end)

    client_data =
      Jason.encode!(%{
        "type" => "webauthn.create",
        "challenge" => url64(challenge_bytes),
        "origin" => origin,
        "crossOrigin" => false
      })

    flags = <<Keyword.get(opts, :flags, 0x41)>>
    sign_count = <<0::unsigned-big-integer-size(32)>>
    aaguid = <<0::128>>
    cred_id_length = <<byte_size(credential_id)::unsigned-big-integer-size(16)>>
    cose_key_cbor = cose_key |> CBOR.encode() |> IO.iodata_to_binary()

    auth_data =
      :crypto.hash(:sha256, rp_id) <>
        flags <> sign_count <> aaguid <> cred_id_length <> credential_id <> cose_key_cbor

    attestation_object =
      %{"fmt" => "none", "attStmt" => %{}, "authData" => auth_data}
      |> CBOR.encode()
      |> IO.iodata_to_binary()

    %{
      credential_id: credential_id,
      cose_key: cose_key,
      private_key: private_key,
      user_handle: nil,
      attestation_object: url64(attestation_object),
      client_data_json: url64(client_data),
      raw_id: url64(credential_id)
    }
  end

  @doc """
  An assertion signed by `passkey`.

  Options: `:origin`, `:rp_id`, `:challenge_bytes`, `:sign_count` (default
  `1`), `:flags` (default `0x05`: UP + UV).
  """
  @spec generate_authentication(passkey, keyword) :: map
  def generate_authentication(passkey, opts) do
    origin = Keyword.fetch!(opts, :origin)
    rp_id = Keyword.fetch!(opts, :rp_id)
    sign_count = Keyword.get(opts, :sign_count, 1)

    challenge_bytes =
      Keyword.get_lazy(opts, :challenge_bytes, fn -> :crypto.strong_rand_bytes(32) end)

    client_data =
      Jason.encode!(%{
        "type" => "webauthn.get",
        "challenge" => url64(challenge_bytes),
        "origin" => origin,
        "crossOrigin" => false
      })

    flags = <<Keyword.get(opts, :flags, 0x05)>>

    auth_data =
      :crypto.hash(:sha256, rp_id) <> flags <> <<sign_count::unsigned-big-integer-size(32)>>

    # The authenticator signs authenticatorData || SHA-256(clientDataJSON).
    signature =
      :public_key.sign(
        auth_data <> :crypto.hash(:sha256, client_data),
        :sha256,
        passkey.private_key
      )

    %{
      raw_id: passkey.credential_id,
      authenticator_data: url64(auth_data),
      signature: url64(signature),
      client_data_json: url64(client_data),
      sign_count: sign_count
    }
  end

  defp url64(binary), do: Base.url_encode64(binary, padding: false)
end
