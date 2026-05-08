# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.WebAuthnHelpers do
  @moduledoc """
  Helper functions for working with WebAuthn second-factor authentication.

  These helpers can be used in plugs, LiveView on_mount hooks, and templates
  to check whether a user has a passkey registered (`webauthn_configured?`)
  and whether the current request has been verified by a passkey ceremony
  (`webauthn_verified?`).

  See the [Passkeys as 2FA](webauthn-2fa.md) guide for the full flow.
  """

  alias AshAuthentication.Info
  alias AshAuthentication.Strategy.WebAuthn
  alias Phoenix.LiveView.Socket
  alias Plug.Conn

  @doc """
  Returns `true` if the user has at least one registered WebAuthn credential.

  Walks the strategy's `credentials_relationship_name` (loading it if it
  isn't already loaded). Returns `false` for `nil` users so callers don't
  have to nil-check first.

  ## Options

    * `:strategy` — the WebAuthn strategy to check against. Defaults to the
      first WebAuthn strategy on the user's resource.
  """
  @spec webauthn_configured?(nil | Ash.Resource.record(), keyword()) :: boolean()
  def webauthn_configured?(user, opts \\ [])
  def webauthn_configured?(nil, _opts), do: false

  def webauthn_configured?(user, opts) when is_struct(user) do
    with {:ok, strategy} <- get_webauthn_strategy(user.__struct__, opts),
         {:ok, credentials} <- fetch_credentials(user, strategy.credentials_relationship_name) do
      Enum.any?(credentials)
    else
      _ -> false
    end
  end

  defp fetch_credentials(user, relationship_name) do
    case Map.get(user, relationship_name) do
      %Ash.NotLoaded{} -> load_credentials(user, relationship_name)
      credentials when is_list(credentials) -> {:ok, credentials}
      _ -> :error
    end
  end

  defp load_credentials(user, relationship_name) do
    case Ash.load(user, [relationship_name],
           authorize?: false,
           domain: Info.domain!(user.__struct__)
         ) do
      {:ok, loaded} -> {:ok, Map.get(loaded, relationship_name, [])}
      _ -> :error
    end
  end

  @doc """
  Returns `true` if the current request has a WebAuthn verification on it.

  Accepts either:

    * a `Plug.Conn` — looks at the assign named by `:current_user_assign`
      (default `:current_user`).
    * a `Phoenix.LiveView.Socket` — same, against `socket.assigns`.
    * a user struct — checks its `__metadata__[:webauthn_verified_at]`
      directly. Useful in `AuthController.success/4` clauses where you
      have the user but no conn / socket.

  ## Options

    * `:max_age` — maximum age of the verification in seconds. `nil`
      (default) means no expiry; any timestamp counts.
    * `:current_user_assign` — assign holding the user (conn / socket
      forms only). Defaults to `:current_user`.
  """
  @spec webauthn_verified?(Conn.t() | Socket.t() | struct() | nil, keyword()) :: boolean()
  def webauthn_verified?(conn_or_socket_or_user, opts \\ [])

  def webauthn_verified?(nil, _opts), do: false
  def webauthn_verified?(%Conn{} = conn, opts), do: verified?(conn.assigns, opts)
  def webauthn_verified?(%Socket{} = socket, opts), do: verified?(socket.assigns, opts)

  def webauthn_verified?(%_{} = user, opts) do
    within_max_age?(verified_at(user), Keyword.get(opts, :max_age))
  end

  defp verified?(assigns, opts) do
    user_assign = Keyword.get(opts, :current_user_assign, :current_user)
    max_age = Keyword.get(opts, :max_age)

    case Map.get(assigns, user_assign) do
      nil -> false
      user -> within_max_age?(verified_at(user), max_age)
    end
  end

  defp verified_at(%{__metadata__: metadata}) do
    Map.get(metadata || %{}, :webauthn_verified_at)
  end

  defp verified_at(_), do: nil

  defp within_max_age?(nil, _max_age), do: false

  defp within_max_age?(%DateTime{}, nil), do: true

  defp within_max_age?(%DateTime{} = verified_at, max_age)
       when is_integer(max_age) and max_age >= 0 do
    DateTime.diff(DateTime.utc_now(), verified_at, :second) <= max_age
  end

  defp within_max_age?(verified_at, max_age) when is_binary(verified_at) do
    case DateTime.from_iso8601(verified_at) do
      {:ok, dt, _} -> within_max_age?(dt, max_age)
      _ -> false
    end
  end

  defp within_max_age?(_, _), do: false

  @doc """
  Returns the WebAuthn strategy on a resource, if any.

  ## Options

    * `:strategy` — return the named strategy. If unset, returns the first
      WebAuthn strategy.
  """
  @spec get_webauthn_strategy(module(), keyword()) ::
          {:ok, WebAuthn.t()} | {:error, :no_webauthn_strategy}
  def get_webauthn_strategy(resource, opts \\ []) when is_atom(resource) do
    strategy_name = Keyword.get(opts, :strategy)

    strategies =
      resource
      |> Info.authentication_strategies()
      |> Enum.filter(&match?(%WebAuthn{}, &1))

    case {strategy_name, strategies} do
      {nil, [strategy | _]} ->
        {:ok, strategy}

      {name, strategies} when is_atom(name) ->
        case Enum.find(strategies, &(&1.name == name)) do
          nil -> {:error, :no_webauthn_strategy}
          strategy -> {:ok, strategy}
        end

      {_, []} ->
        {:error, :no_webauthn_strategy}
    end
  end

  @doc """
  Returns `true` if the resource has a WebAuthn strategy configured.
  """
  @spec webauthn_available?(module()) :: boolean()
  def webauthn_available?(resource) when is_atom(resource) do
    case get_webauthn_strategy(resource) do
      {:ok, _} -> true
      _ -> false
    end
  end
end
