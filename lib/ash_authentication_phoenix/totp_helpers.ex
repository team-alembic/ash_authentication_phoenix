# SPDX-FileCopyrightText: 2024 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.TotpHelpers do
  @moduledoc """
  Helper functions for working with TOTP two-factor authentication.

  These helpers can be used in plugs, LiveView on_mount hooks, and templates
  to check if a user has TOTP configured and make decisions about requiring
  two-factor authentication.

  ## Usage in Plugs

      defmodule MyAppWeb.RequireTotpPlug do
        import Plug.Conn
        import AshAuthentication.Phoenix.TotpHelpers

        def init(opts), do: opts

        def call(conn, _opts) do
          user = conn.assigns[:current_user]

          if user && totp_configured?(user) do
            conn
          else
            conn
            |> put_flash(:error, "Please configure two-factor authentication")
            |> redirect(to: "/auth/totp/setup")
            |> halt()
          end
        end
      end

  ## Usage in LiveView

      def mount(_params, session, socket) do
        socket = assign_new(socket, :current_user, fn -> get_user_from_session(session) end)
        user = socket.assigns.current_user

        if user && AshAuthentication.Phoenix.TotpHelpers.totp_configured?(user) do
          {:ok, socket}
        else
          {:ok, push_redirect(socket, to: "/auth/totp/setup")}
        end
      end
  """

  alias AshAuthentication.Info
  alias AshAuthentication.Strategy.Totp

  @doc """
  Returns true if the user has TOTP configured.

  This checks if the TOTP secret field on the user resource has a value.

  ## Options

    * `:strategy` - The TOTP strategy to check against. If not provided,
      the first TOTP strategy for the resource will be used.

  ## Examples

      iex> totp_configured?(user)
      true

      iex> totp_configured?(user, strategy: :backup_totp)
      false
  """
  @spec totp_configured?(Ash.Resource.record(), keyword()) :: boolean()
  def totp_configured?(user, opts \\ []) when is_struct(user) do
    case get_totp_strategy(user.__struct__, opts) do
      {:ok, strategy} ->
        secret = Map.get(user, strategy.secret_field)
        is_binary(secret) and byte_size(secret) > 0

      _ ->
        false
    end
  end

  @doc """
  Returns the TOTP strategy for a resource.

  ## Options

    * `:strategy` - The specific strategy name to look for. If not provided,
      returns the first TOTP strategy found.

  ## Examples

      iex> get_totp_strategy(MyApp.User)
      {:ok, %AshAuthentication.Strategy.Totp{...}}

      iex> get_totp_strategy(MyApp.User, strategy: :totp)
      {:ok, %AshAuthentication.Strategy.Totp{...}}

      iex> get_totp_strategy(MyApp.Resource.WithoutTotp)
      {:error, :no_totp_strategy}
  """
  @spec get_totp_strategy(module(), keyword()) :: {:ok, Totp.t()} | {:error, :no_totp_strategy}
  def get_totp_strategy(resource, opts \\ []) when is_atom(resource) do
    strategy_name = Keyword.get(opts, :strategy)

    strategies =
      resource
      |> Info.authentication_strategies()
      |> Enum.filter(&match?(%Totp{}, &1))

    case {strategy_name, strategies} do
      {nil, [strategy | _]} ->
        {:ok, strategy}

      {name, strategies} when is_atom(name) ->
        case Enum.find(strategies, &(&1.name == name)) do
          nil -> {:error, :no_totp_strategy}
          strategy -> {:ok, strategy}
        end

      {_, []} ->
        {:error, :no_totp_strategy}
    end
  end

  @doc """
  Returns true if TOTP is available for the given resource.

  ## Examples

      iex> totp_available?(MyApp.User)
      true

      iex> totp_available?(MyApp.Resource.WithoutTotp)
      false
  """
  @spec totp_available?(module()) :: boolean()
  def totp_available?(resource) when is_atom(resource) do
    case get_totp_strategy(resource) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Returns the secret field name for the TOTP strategy.

  ## Options

    * `:strategy` - The specific strategy name. Defaults to the first TOTP strategy.

  ## Examples

      iex> totp_secret_field(MyApp.User)
      {:ok, :totp_secret}
  """
  @spec totp_secret_field(module(), keyword()) :: {:ok, atom()} | {:error, :no_totp_strategy}
  def totp_secret_field(resource, opts \\ []) when is_atom(resource) do
    case get_totp_strategy(resource, opts) do
      {:ok, strategy} -> {:ok, strategy.secret_field}
      error -> error
    end
  end
end
