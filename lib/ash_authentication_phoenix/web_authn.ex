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

  ## Origins

  Nothing here reads the request's origin. Which origins a ceremony is
  accepted from is the strategy's own policy — its configured `origin`
  allowlist, or, when none is configured, any `https` origin on its `rp_id`
  or a subdomain of it (see `AshAuthentication.Strategy.WebAuthn.Origin`).
  The browser signs the page's origin into every ceremony and the adapter
  checks it against that policy, so a LiveView served behind a
  TLS-terminating proxy needs no help from the socket's `host_uri`.

  ## Cross-device (hybrid) passkeys

  The strategy's `hints` option is carried through to the browser on both
  ceremonies, so configuring it in `ash_authentication` is all that is needed
  here:

  ```elixir
  webauthn :webauthn do
    hints [:hybrid, :security_key]
    timeout 300_000
  end
  ```

  `:hybrid` asks for the "use your phone or tablet" option, which shows a QR
  code and completes the ceremony on a passkey held by another device. Allow a
  generous `timeout` — the default 60s cannot fit a QR scan, a Bluetooth
  handshake and a prompt on the second device, and the ceremony expires
  mid-scan. Chrome 128+ honours `hints`; other browsers ignore members they
  don't recognise and fall back to their own picker, so no feature detection is
  needed.

  When the strategy lets the client choose with `allow_hint_override? true`,
  every ceremony component also renders one secondary action beside its main
  button, pointing away from where the configured hints lead (see
  `secondary_hint/1`): "Use a phone or tablet" asks for `hints: [:hybrid]`,
  "Use a passkey on this device" for `hints: [:client_device]`.
  `resolve_hints/2` honours the request only when the override is allowed —
  otherwise the configured hints stand, exactly as the strategy's own
  challenge endpoints treat a `?hints=` request parameter — which is why no
  secondary action is offered without it.

  ## Ceremony timeouts

  The strategy's `timeout` is the one bound on a ceremony: the browser gets it
  in the options, the server rejects a challenge answered after it, and the
  components give up waiting for the browser after it. Nothing here hardcodes
  a duration.
  """

  alias Ash.Resource.Info, as: ResourceInfo
  alias AshAuthentication.Info
  alias AshAuthentication.Strategy.WebAuthn
  alias AshAuthentication.Strategy.WebAuthn.Helpers

  @doc """
  The signed-in record of `resource`, as `AshAuthentication.Phoenix.LiveSession`
  assigned it to the socket: `current_<subject_name>`, which is `current_user`
  only for a resource whose subject name is `user`. `nil` when nobody is
  signed in, or when `resource` is `nil`.
  """
  @spec current_subject(Phoenix.LiveView.Socket.t(), Ash.Resource.t() | nil) :: struct | nil
  def current_subject(_socket, nil), do: nil

  def current_subject(socket, resource) do
    subject_name = Info.authentication_subject_name!(resource)
    socket.assigns[String.to_atom("current_#{subject_name}")]
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
  The one secondary action a ceremony form should offer beside its main
  button for `strategy`: `:hybrid` ("Use a phone or tablet"),
  `:client_device` ("Use a passkey on this device"), or `nil` for none.

  A secondary action is only worth rendering when it changes the ceremony.
  The strategy must let the client choose (`allow_hint_override?`), or the
  request would be ignored and the button would do exactly what the main one
  does. Given that, the button points away from where the configured hints
  lead: with `:hybrid` first the browser already opens on the phone's QR
  code, so the alternative is a passkey on this device; otherwise the browser
  leads with whatever is configured — or its own picker, when nothing is —
  and the alternative is the phone. `authenticator_attachment :platform`
  rules out every roaming authenticator, a phone included, so nothing is
  offered then.
  """
  @spec secondary_hint(struct) :: :hybrid | :client_device | nil
  def secondary_hint(%{authenticator_attachment: :platform}), do: nil

  def secondary_hint(%{allow_hint_override?: true, hints: [:hybrid | _]}), do: :client_device
  def secondary_hint(%{allow_hint_override?: true}), do: :hybrid
  def secondary_hint(_strategy), do: nil

  @doc """
  The hints a ceremony is issued with: the ones the client requested when
  the strategy's `allow_hint_override?` permits, otherwise the strategy's own.

  Mirrors the strategy's challenge endpoints and their `?hints=` parameter:
  `requested` may be a list of hint atoms or strings, or one string of
  comma-separated hints; anything outside the hint enum is dropped, and a
  request naming nothing valid falls back to the configured hints. Safe to
  take from the client, since `hints` only steers the dialog the requesting
  browser shows itself.
  """
  @spec resolve_hints(struct, nil | String.t() | [atom | String.t()]) :: [atom]
  def resolve_hints(strategy, requested) do
    with true <- strategy.allow_hint_override? == true,
         [_ | _] = hints <- requested_hints(requested) do
      hints
    else
      _ -> strategy.hints
    end
  end

  @hint_atoms %{
    "security-key" => :security_key,
    "security_key" => :security_key,
    "client-device" => :client_device,
    "client_device" => :client_device,
    "hybrid" => :hybrid
  }

  @hint_strings %{
    security_key: "security-key",
    client_device: "client-device",
    hybrid: "hybrid"
  }

  defp requested_hints(requested) do
    requested
    |> List.wrap()
    |> Enum.flat_map(fn
      hint when is_binary(hint) -> String.split(hint, ",", trim: true)
      hint when is_atom(hint) and not is_nil(hint) -> [Atom.to_string(hint)]
      _ -> []
    end)
    |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
    |> Enum.flat_map(&List.wrap(Map.get(@hint_atoms, &1)))
    |> Enum.uniq()
  end

  @doc """
  The `hints` form value that asks for `hint`, spelled as the
  `PublicKeyCredentialHint` enum spells it and as `resolve_hints/2` reads
  it back.
  """
  @spec hint_param(:hybrid | :client_device | :security_key) :: String.t()
  def hint_param(hint), do: Map.fetch!(@hint_strings, hint)

  @doc """
  Build the spec-shaped `PublicKeyCredentialCreationOptions` payload for a
  registration ceremony, ready for `push_event/3` to the
  `WebAuthnRegistrationHook`.

  Options:

    * `:hints` — hints the client requested for this one ceremony, resolved
      against the strategy with `resolve_hints/2`.
    * `:context` — the Ash context the request carries, which an
      `AshAuthentication.Secret` resolving `rp_id` or `rp_name` receives
      (with the tenant added), as it does from the strategy's own
      challenge calls. `nil` counts as none.
  """
  @spec registration_options(struct, term, any, map, [binary], keyword) :: map
  def registration_options(
        strategy,
        challenge,
        tenant,
        user_descriptor,
        exclude_credential_ids,
        opts \\ []
      ) do
    context = context(opts)

    %{
      challenge: Base.url_encode64(strategy.adapter.challenge_bytes(challenge), padding: false),
      rp: %{
        id: Helpers.resolve_rp_id(strategy, tenant, context),
        name: Helpers.resolve_rp_name(strategy, tenant, context)
      },
      user: user_descriptor,
      # The algorithms the strategy's adapter can verify, in its order of
      # preference; the default adapter's list is not assumed here.
      pubKeyCredParams: strategy.adapter.pub_key_cred_params(),
      excludeCredentials:
        Enum.map(
          exclude_credential_ids,
          &%{id: Base.url_encode64(&1, padding: false), type: "public-key"}
        ),
      authenticatorSelection: authenticator_selection(strategy),
      extensions: %{credProps: true},
      attestation: strategy.attestation,
      timeout: strategy.timeout
    }
    |> put_hints(hints(strategy, opts))
  end

  @doc """
  Build the spec-shaped `PublicKeyCredentialRequestOptions` payload for an
  authentication ceremony, ready for `push_event/3` to the
  `WebAuthnAuthenticationHook`.

  `credentials` are credential records used to build `allowCredentials`
  entries (with `transports` hints when captured at registration); pass
  `[]` for the discoverable-credential flow. `opts` are as for
  `registration_options/6`.
  """
  @spec authentication_options(struct, term, any, [Ash.Resource.Record.t()], keyword) :: map
  def authentication_options(strategy, challenge, tenant, credentials, opts \\ []) do
    %{
      challenge: Base.url_encode64(strategy.adapter.challenge_bytes(challenge), padding: false),
      rpId: Helpers.resolve_rp_id(strategy, tenant, context(opts)),
      userVerification: strategy.user_verification,
      timeout: strategy.timeout,
      allowCredentials: allow_credentials_entries(strategy, credentials)
    }
    |> put_hints(hints(strategy, opts))
  end

  @doc """
  Address pushed ceremony options to one hook element.

  LiveView dispatches a pushed event to every hook on the page that listens
  for its name, so a page holding two ceremony components (two strategies,
  or a credential manager beside a registration form) would start both
  browsers prompts from one click. The hooks ignore options whose `target`
  is not their own element's id, and strip the key before handing the
  options to the browser.
  """
  @spec target(map, String.t()) :: map
  def target(options, element_id) when is_binary(element_id),
    do: Map.put(options, :target, element_id)

  # `authenticatorAttachment` is a three-valued enum with no member for "no
  # preference" — the absence of the key is how that is expressed, and `null`
  # is not a legal value. Sending it explicitly also competes with `hints`,
  # which supersedes it.
  defp authenticator_selection(strategy) do
    %{
      userVerification: strategy.user_verification,
      residentKey: strategy.resident_key,
      # The Level 1 spelling, for clients predating `residentKey`.
      requireResidentKey: strategy.resident_key == :required
    }
    |> maybe_put(:authenticatorAttachment, attachment(strategy.authenticator_attachment))
  end

  # The DSL spells this option in snake case; the enum member is hyphenated,
  # and a client which doesn't recognise the value ignores the whole member.
  defp attachment(:cross_platform), do: "cross-platform"
  defp attachment(:platform), do: "platform"
  defp attachment(nil), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # The Secret helpers want a map; a component whose host passed no context
  # has `nil` or `%{}`, which both mean the same thing here.
  defp context(opts), do: Keyword.get(opts, :context) || %{}

  # Which kinds of authenticator the browser should offer, in order of
  # preference: the client's request for this ceremony when the strategy
  # allows it, otherwise the strategy's own. `:hybrid` is what produces the
  # "use your phone or tablet" QR option — see the `hints` option on the
  # WebAuthn strategy.
  defp hints(strategy, opts) do
    strategy
    |> resolve_hints(Keyword.get(opts, :hints))
    |> Enum.map(&Map.fetch!(@hint_strings, &1))
  end

  # An empty `hints` means "no preference", which is spelled by leaving the
  # member out — an empty sequence reads to some clients as "nothing is
  # acceptable".
  defp put_hints(options, []), do: options
  defp put_hints(options, hints), do: Map.put(options, :hints, hints)

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
