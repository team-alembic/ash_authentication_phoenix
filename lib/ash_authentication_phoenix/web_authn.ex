# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.WebAuthn do
  @moduledoc """
  Helpers shared between the WebAuthn LiveView components.

  The option-building helpers mirror the wire contract of
  `AshAuthentication.Strategy.WebAuthn.Plug` so the same JS hooks work
  against both the Plug JSON endpoints and LiveView `push_event/3`
  payloads: spec-shaped `PublicKeyCredentialCreationOptions` /
  `PublicKeyCredentialRequestOptions` with all binary fields encoded as
  base64url without padding.
  """

  alias Ash.Resource.Info, as: ResourceInfo
  alias AshAuthentication.Info
  alias AshAuthentication.Strategy.WebAuthn
  alias AshAuthentication.Strategy.WebAuthn.Helpers

  # COSE algorithms the default (Wax) adapter can verify, in preference
  # order. Kept in sync with AshAuthentication.Strategy.WebAuthn.Plug.
  @pub_key_cred_params Enum.map(
                         [-7, -8, -35, -36, -37, -38, -39, -257, -258, -259],
                         &%{type: "public-key", alg: &1}
                       )

  @doc """
  Build a WebAuthn origin string from the LiveView socket's `host_uri`.

  Used to override the strategy's configured origin with the actual request
  origin during a ceremony, so dev/test environments don't need a hardcoded
  port baked into config.
  """
  @spec origin_from_socket(Phoenix.LiveView.Socket.t()) :: String.t()
  def origin_from_socket(%Phoenix.LiveView.Socket{host_uri: %URI{} = uri}),
    do: uri_to_origin(uri)

  defp uri_to_origin(%URI{scheme: scheme, host: host, port: port}) do
    port_segment =
      cond do
        scheme == "http" and port == 80 -> ""
        scheme == "https" and port == 443 -> ""
        is_nil(port) -> ""
        true -> ":#{port}"
      end

    "#{scheme}://#{host}#{port_segment}"
  end

  @doc """
  Resolve the `webauthn_path` sign-in route option for a given strategy.

  The option is either a single path (applied to every WebAuthn strategy) or
  a keyword list / map keyed by the resource's authentication subject name,
  for apps with WebAuthn strategies on more than one resource:

  ```elixir
  sign_in_route webauthn_path: [user: "/webauthn", admin: "/admin/webauthn"]
  ```

  Returns `nil` when no path applies — the strategy then renders its full
  inline form instead of a link.
  """
  @spec resolve_path(nil | String.t() | keyword | map, struct) :: String.t() | nil
  def resolve_path(nil, _strategy), do: nil
  def resolve_path(path, _strategy) when is_binary(path), do: path

  def resolve_path(paths, strategy) when is_list(paths) or is_map(paths) do
    subject_name = Info.authentication_subject_name!(strategy.resource)

    paths
    |> Enum.find(fn {subject, _path} -> subject == subject_name end)
    |> case do
      {_subject, path} -> path
      nil -> nil
    end
  end

  @doc """
  Build a user descriptor (and its raw user handle) for a brand-new user.

  The handle is 32 random bytes — an opaque identifier without PII, as the
  spec requires. Pass the returned handle as `user_handle:` to
  `AshAuthentication.Strategy.WebAuthn.Actions.register/3` so it is
  persisted with the credential.

  `name` is the account identifier password managers show as the
  "username" of the saved passkey; `display_name` is the friendly label.
  In identity mode the identity value is the natural `name`. In
  passkey-first mode there is no identity, so the user-chosen passkey name
  is used instead — it is what the user expects the saved key to be
  labelled as, and it must be baked in before the ceremony because most
  password managers don't allow renaming afterwards. `display_name` fills
  whichever slots remain.
  """
  @spec new_user_descriptor(String.t() | nil, String.t() | nil, String.t() | nil) ::
          {map, binary}
  def new_user_descriptor(identity, display_name, passkey_name \\ nil) do
    identity = presence(identity)
    display_name = presence(display_name)
    passkey_name = presence(passkey_name)
    name = identity || passkey_name || display_name || "user"
    handle = :crypto.strong_rand_bytes(32)

    {%{
       id: Base.url_encode64(handle, padding: false),
       name: name,
       displayName: display_name || passkey_name || name
     }, handle}
  end

  @doc """
  Build a user descriptor (and its raw user handle) for an existing user
  adding another credential.

  The handle must be stable so all of the user's passkeys share it: reuses
  the handle stored with an existing credential when there is one,
  otherwise falls back to the primary key. Pass the returned handle as
  `user_handle:` to
  `AshAuthentication.Strategy.WebAuthn.Actions.add_credential/3`.

  `name` is the identity value when the resource has one; for
  identity-less (passkey-first) users the given passkey name is preferred
  over the primary key, so password managers label the saved key with
  something meaningful rather than a UUID.
  """
  @spec actor_user_descriptor(
          struct,
          Ash.Resource.Record.t(),
          [Ash.Resource.Record.t()],
          String.t() | nil
        ) :: {map, binary}
  def actor_user_descriptor(strategy, actor, credentials, passkey_name \\ nil) do
    [primary_key] = ResourceInfo.primary_key(strategy.resource)

    user_handle_field = WebAuthn.user_handle_field(strategy)

    handle =
      Enum.find_value(credentials, &Map.get(&1, user_handle_field)) ||
        actor |> Map.fetch!(primary_key) |> to_string()

    name =
      case Map.get(actor, strategy.identity_field) do
        nil ->
          presence(passkey_name) || actor |> Map.fetch!(primary_key) |> to_string()

        value ->
          to_string(value)
      end

    {%{
       id: Base.url_encode64(handle, padding: false),
       name: name,
       displayName: name
     }, handle}
  end

  @doc """
  Build the spec-shaped `PublicKeyCredentialCreationOptions` payload for a
  registration ceremony, ready for `push_event/3` to the
  `WebAuthnRegistrationHook`.
  """
  @spec registration_options(struct, term, any, map, [binary]) :: map
  def registration_options(strategy, challenge, tenant, user_descriptor, exclude_credential_ids) do
    %{
      challenge: Base.url_encode64(strategy.adapter.challenge_bytes(challenge), padding: false),
      rp: %{
        id: Helpers.resolve_rp_id(strategy, tenant),
        name: Helpers.resolve_rp_name(strategy, tenant)
      },
      user: user_descriptor,
      pubKeyCredParams: @pub_key_cred_params,
      excludeCredentials:
        Enum.map(
          exclude_credential_ids,
          &%{id: Base.url_encode64(&1, padding: false), type: "public-key"}
        ),
      authenticatorSelection: %{
        authenticatorAttachment: strategy.authenticator_attachment,
        userVerification: strategy.user_verification,
        residentKey: strategy.resident_key
      },
      extensions: %{credProps: true},
      attestation: strategy.attestation,
      timeout: strategy.timeout
    }
  end

  @doc """
  Build the spec-shaped `PublicKeyCredentialRequestOptions` payload for an
  authentication ceremony, ready for `push_event/3` to the
  `WebAuthnAuthenticationHook`.

  `credentials` are credential records used to build `allowCredentials`
  entries (with `transports` hints when captured at registration); pass
  `[]` for the discoverable-credential flow.
  """
  @spec authentication_options(struct, term, any, [Ash.Resource.Record.t()]) :: map
  def authentication_options(strategy, challenge, tenant, credentials) do
    %{
      challenge: Base.url_encode64(strategy.adapter.challenge_bytes(challenge), padding: false),
      rpId: Helpers.resolve_rp_id(strategy, tenant),
      userVerification: strategy.user_verification,
      timeout: strategy.timeout,
      allowCredentials: allow_credentials_entries(strategy, credentials)
    }
  end

  # allowCredentials entries sent to the browser. Transports hints (when
  # captured at registration) let the client route straight to the right
  # authenticator instead of prompting for every kind it supports.
  defp allow_credentials_entries(_strategy, []), do: []

  defp allow_credentials_entries(strategy, credentials) do
    # Both accessors walk the credential resource's DSL, so resolve them once
    # rather than per credential.
    credential_id_field = WebAuthn.credential_id_field(strategy)
    transports_field = WebAuthn.transports_field(strategy)

    Enum.map(credentials, fn cred ->
      entry = %{
        id: Base.url_encode64(Map.get(cred, credential_id_field), padding: false),
        type: "public-key"
      }

      case Map.get(cred, transports_field) do
        [_ | _] = transports -> Map.put(entry, :transports, transports)
        _ -> entry
      end
    end)
  end

  defp presence(value) when is_binary(value) and value != "", do: value
  defp presence(_), do: nil
end
