# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.LiveSessionTest do
  @moduledoc false

  use ExUnit.Case, async: false
  alias AshAuthentication.Phoenix.LiveSession

  describe "on_mount with multiple authenticated resources" do
    test "loads first resource when only user credentials present" do
      user =
        Example.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "user-test1@example.com",
          password: "secure-password",
          password_confirmation: "secure-password"
        })
        |> Ash.create!()

      subject = AshAuthentication.user_to_subject(user)

      # Add JTI prefix since User resource uses session_identifier(:jti)
      jti_subject = "fake-jti:#{subject}"

      session = %{
        "user" => jti_subject
      }

      socket = build_socket()
      {:cont, result_socket} = LiveSession.on_mount(:default, %{}, session, socket)

      assert result_socket.assigns.current_user.id == user.id
      assert Map.get(result_socket.assigns, :current_admin) == nil
    end

    test "loads second resource when only admin credentials present" do
      admin =
        Example.Accounts.Admin
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "admin-test2@example.com",
          password: "secure-password",
          password_confirmation: "secure-password"
        })
        |> Ash.create!()

      admin_subject = "fake-jti:#{AshAuthentication.user_to_subject(admin)}"

      session = %{
        "admin" => admin_subject
      }

      socket = build_socket()
      {:cont, result_socket} = LiveSession.on_mount(:default, %{}, session, socket)

      assert result_socket.assigns.current_admin.id == admin.id
      assert Map.get(result_socket.assigns, :current_user) == nil
    end

    test "loads both resources when both credentials present" do
      user =
        Example.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "user-test3@example.com",
          password: "secure-password",
          password_confirmation: "secure-password"
        })
        |> Ash.create!()

      admin =
        Example.Accounts.Admin
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "admin-test3@example.com",
          password: "secure-password",
          password_confirmation: "secure-password"
        })
        |> Ash.create!()

      user_subject = "fake-jti:#{AshAuthentication.user_to_subject(user)}"
      admin_subject = "fake-jti:#{AshAuthentication.user_to_subject(admin)}"

      session = %{
        "user" => user_subject,
        "admin" => admin_subject
      }

      socket = build_socket()
      {:cont, result_socket} = LiveSession.on_mount(:default, %{}, session, socket)

      assert result_socket.assigns.current_user.id == user.id
      assert result_socket.assigns.current_admin.id == admin.id
    end

    test "loads no resources when session is empty" do
      session = %{}

      socket = build_socket()
      {:cont, result_socket} = LiveSession.on_mount(:default, %{}, session, socket)

      assert Map.get(result_socket.assigns, :current_user) == nil
      assert Map.get(result_socket.assigns, :current_admin) == nil
    end

    test "loads no resources when credentials are invalid" do
      session = %{
        "user" => "fake-jti:user?id=nonexistent-id",
        "admin" => "fake-jti:admin?id=another-nonexistent-id"
      }

      socket = build_socket()
      {:cont, result_socket} = LiveSession.on_mount(:default, %{}, session, socket)

      assert Map.get(result_socket.assigns, :current_user) == nil
      assert Map.get(result_socket.assigns, :current_admin) == nil
    end

    test "assigns nil when no credentials are present" do
      socket = build_socket()
      {:cont, result_socket} = LiveSession.on_mount(:default, %{}, %{}, socket)

      assert Map.fetch!(result_socket.assigns, :current_user) == nil
      assert Map.fetch!(result_socket.assigns, :current_admin) == nil
    end

    test "loads valid resource and skips invalid one (user valid, admin invalid)" do
      user =
        Example.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "user-test6@example.com",
          password: "secure-password",
          password_confirmation: "secure-password"
        })
        |> Ash.create!()

      user_subject = "fake-jti:#{AshAuthentication.user_to_subject(user)}"

      session = %{
        "user" => user_subject,
        "admin" => "fake-jti:admin?id=nonexistent-id"
      }

      socket = build_socket()
      {:cont, result_socket} = LiveSession.on_mount(:default, %{}, session, socket)

      assert result_socket.assigns.current_user.id == user.id
      assert Map.get(result_socket.assigns, :current_admin) == nil
    end

    test "loads valid resource and skips invalid one (admin valid, user invalid)" do
      admin =
        Example.Accounts.Admin
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "admin-test7@example.com",
          password: "secure-password",
          password_confirmation: "secure-password"
        })
        |> Ash.create!()

      admin_subject = "fake-jti:#{AshAuthentication.user_to_subject(admin)}"

      session = %{
        "user" => "fake-jti:user?id=nonexistent-id",
        "admin" => admin_subject
      }

      socket = build_socket()
      {:cont, result_socket} = LiveSession.on_mount(:default, %{}, session, socket)

      assert result_socket.assigns.current_admin.id == admin.id
      assert Map.get(result_socket.assigns, :current_user) == nil
    end
  end

  describe "on_mount with a scope module" do
    test "wraps each loaded subject in a scope assign" do
      user =
        Example.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "scope-user@example.com",
          password: "secure-password",
          password_confirmation: "secure-password"
        })
        |> Ash.create!()

      session = %{
        "user" => "fake-jti:#{AshAuthentication.user_to_subject(user)}",
        "scope" => Example.Accounts.Scope
      }

      socket = build_socket()
      {:cont, result_socket} = LiveSession.on_mount(:default, %{}, session, socket)

      scope = result_socket.assigns.current_user_scope
      assert %Example.Accounts.Scope{} = scope
      assert scope.actor.id == user.id
      assert {:ok, actor} = Ash.Scope.ToOpts.get_actor(scope)
      assert actor.id == user.id
    end

    test "assigns an anonymous scope when the subject is absent" do
      session = %{"scope" => Example.Accounts.Scope}

      socket = build_socket()
      {:cont, result_socket} = LiveSession.on_mount(:default, %{}, session, socket)

      assert %Example.Accounts.Scope{actor: nil} = result_socket.assigns.current_user_scope
    end

    test "does not assign scopes when no scope module is provided" do
      session = %{"user" => "fake-jti:user?id=nonexistent-id"}

      socket = build_socket()
      {:cont, result_socket} = LiveSession.on_mount(:default, %{}, session, socket)

      refute Map.has_key?(result_socket.assigns, :current_user_scope)
    end

    test "assigns current_scope alias for the default_scope subject" do
      user =
        Example.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "scope-alias-user@example.com",
          password: "secure-password",
          password_confirmation: "secure-password"
        })
        |> Ash.create!()

      session = %{
        "user" => "fake-jti:#{AshAuthentication.user_to_subject(user)}",
        "scope" => Example.Accounts.Scope,
        "default_scope" => "user"
      }

      socket = build_socket()
      {:cont, result_socket} = LiveSession.on_mount(:default, %{}, session, socket)

      assert result_socket.assigns.current_scope == result_socket.assigns.current_user_scope
      assert result_socket.assigns.current_scope.actor.id == user.id
    end

    test "does not assign current_scope without a default_scope subject" do
      session = %{"scope" => Example.Accounts.Scope}

      socket = build_socket()
      {:cont, result_socket} = LiveSession.on_mount(:default, %{}, session, socket)

      refute Map.has_key?(result_socket.assigns, :current_scope)
    end
  end

  defp build_socket do
    %Phoenix.LiveView.Socket{
      endpoint: AshAuthentication.Phoenix.Test.Endpoint,
      assigns: %{
        __changed__: %{},
        flash: %{},
        otp_app: :ash_authentication_phoenix
      }
    }
  end
end
