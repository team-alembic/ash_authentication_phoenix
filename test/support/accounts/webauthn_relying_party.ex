# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule Example.Accounts.WebAuthnRelyingParty do
  @moduledoc """
  The `rp_id` Secret of the passkey-only test resource.

  It answers `"localhost"`, like the literal it stands in for, so every
  ceremony works as before. What it adds is a window on the context the
  strategy resolves it with: a test that calls `observe/0` receives
  `{:rp_id_resolved, context}` for every resolution, which is how the suite
  checks that the components hand the request's Ash context to the strategy.
  """

  use AshAuthentication.Secret

  @probe :webauthn_relying_party_probe

  @doc """
  Have the calling process receive `{:rp_id_resolved, context}` for every
  resolution from now on. One observer at a time; a later call takes over.
  """
  @spec observe() :: :ok
  def observe do
    if Process.whereis(@probe), do: Process.unregister(@probe)
    Process.register(self(), @probe)
    :ok
  end

  @doc """
  The contexts reported to the calling process, oldest first, waiting
  briefly for the last of them: the LiveView resolves the secret and
  answers the test through different paths, so the report can trail the
  rendered reply.
  """
  @spec resolved_contexts() :: [map]
  def resolved_contexts do
    receive do
      {:rp_id_resolved, context} -> [context | resolved_contexts()]
    after
      100 -> []
    end
  end

  @impl true
  def secret_for(
        [:authentication, :strategies, :webauthn, :rp_id],
        Example.Accounts.AnonUser,
        _opts,
        context
      ) do
    if probe = Process.whereis(@probe), do: send(probe, {:rp_id_resolved, context})
    {:ok, "localhost"}
  end
end
