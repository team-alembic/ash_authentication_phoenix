# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.WebAuthnHelpersTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AshAuthentication.Phoenix.WebAuthnHelpers

  defmodule FakeUser do
    defstruct id: nil, __metadata__: %{}
  end

  defp conn_with_user(user, max_age \\ nil) do
    %Plug.Conn{assigns: %{current_user: user}, private: %{}}
    |> with_max_age(max_age)
  end

  defp socket_with_user(user, max_age \\ nil) do
    %Phoenix.LiveView.Socket{assigns: %{current_user: user, __changed__: %{}}}
    |> with_max_age(max_age)
  end

  defp with_max_age(thing, _), do: thing

  describe "webauthn_verified?/2 with a Plug.Conn" do
    test "returns false when there is no current_user" do
      conn = %Plug.Conn{assigns: %{}, private: %{}}
      refute WebAuthnHelpers.webauthn_verified?(conn)
    end

    test "returns false when the user metadata has no `:webauthn_verified_at`" do
      user = %FakeUser{__metadata__: %{}}
      refute WebAuthnHelpers.webauthn_verified?(conn_with_user(user))
    end

    test "returns true when the user metadata has a recent timestamp" do
      user = %FakeUser{__metadata__: %{webauthn_verified_at: DateTime.utc_now()}}
      assert WebAuthnHelpers.webauthn_verified?(conn_with_user(user))
    end

    test "returns true when an old timestamp is within `max_age`" do
      verified_at = DateTime.add(DateTime.utc_now(), -10, :second)
      user = %FakeUser{__metadata__: %{webauthn_verified_at: verified_at}}
      assert WebAuthnHelpers.webauthn_verified?(conn_with_user(user), max_age: 60)
    end

    test "returns false when the timestamp is older than `max_age`" do
      verified_at = DateTime.add(DateTime.utc_now(), -120, :second)
      user = %FakeUser{__metadata__: %{webauthn_verified_at: verified_at}}
      refute WebAuthnHelpers.webauthn_verified?(conn_with_user(user), max_age: 60)
    end

    test "respects `:current_user_assign`" do
      verified_at = DateTime.utc_now()
      user = %FakeUser{__metadata__: %{webauthn_verified_at: verified_at}}
      conn = %Plug.Conn{assigns: %{actor: user}, private: %{}}

      assert WebAuthnHelpers.webauthn_verified?(conn, current_user_assign: :actor)
    end

    test "accepts an ISO8601-string timestamp (e.g. straight from a JWT claim)" do
      verified_at = DateTime.utc_now() |> DateTime.to_iso8601()
      user = %FakeUser{__metadata__: %{webauthn_verified_at: verified_at}}
      assert WebAuthnHelpers.webauthn_verified?(conn_with_user(user))
    end
  end

  describe "webauthn_verified?/2 with a Phoenix.LiveView.Socket" do
    test "returns false when no current_user" do
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
      refute WebAuthnHelpers.webauthn_verified?(socket)
    end

    test "returns true with a recent timestamp on the user metadata" do
      user = %FakeUser{__metadata__: %{webauthn_verified_at: DateTime.utc_now()}}
      assert WebAuthnHelpers.webauthn_verified?(socket_with_user(user))
    end
  end

  describe "webauthn_configured?/2" do
    test "returns false for nil" do
      refute WebAuthnHelpers.webauthn_configured?(nil)
    end
  end

  describe "webauthn_verified?/2 with a user struct" do
    test "returns false for nil" do
      refute WebAuthnHelpers.webauthn_verified?(nil)
    end

    test "returns false when the user has no `:webauthn_verified_at` metadata" do
      user = %FakeUser{__metadata__: %{}}
      refute WebAuthnHelpers.webauthn_verified?(user)
    end

    test "returns true when the user has a recent timestamp" do
      user = %FakeUser{__metadata__: %{webauthn_verified_at: DateTime.utc_now()}}
      assert WebAuthnHelpers.webauthn_verified?(user)
    end

    test "respects `:max_age` for a user struct" do
      verified_at = DateTime.add(DateTime.utc_now(), -120, :second)
      user = %FakeUser{__metadata__: %{webauthn_verified_at: verified_at}}
      refute WebAuthnHelpers.webauthn_verified?(user, max_age: 60)
      assert WebAuthnHelpers.webauthn_verified?(user, max_age: 300)
    end
  end
end
