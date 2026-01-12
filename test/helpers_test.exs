# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.HelpersTest do
  @moduledoc false

  use ExUnit.Case, async: false
  use Mimic

  alias AshAuthentication.Phoenix.Components.Helpers
  alias AshAuthentication.Strategy.RememberMe

  describe "remember_me_field/1" do
    test "returns nil when action has no remember_me preparation or change" do
      stub(Ash.Resource.Info, :action, fn _resource, _action_name ->
        %{preparations: [], changes: []}
      end)

      strategy = %{resource: Example.Accounts.User, sign_in_action_name: :sign_in}

      assert Helpers.remember_me_field(strategy) == nil
    end

    test "returns nil when action is not found" do
      stub(Ash.Resource.Info, :action, fn _resource, _action_name -> nil end)

      strategy = %{resource: Example.Accounts.User, sign_in_action_name: :nonexistent}

      assert Helpers.remember_me_field(strategy) == nil
    end

    test "returns field name from MaybeGenerateTokenPreparation in preparations" do
      stub(Ash.Resource.Info, :action, fn _resource, _action_name ->
        %{
          preparations: [
            %Ash.Resource.Preparation{
              preparation: {RememberMe.MaybeGenerateTokenPreparation, [argument: :remember_me]}
            }
          ],
          changes: []
        }
      end)

      strategy = %{resource: Example.Accounts.User, sign_in_action_name: :sign_in}

      assert Helpers.remember_me_field(strategy) == :remember_me
    end

    test "returns custom field name from MaybeGenerateTokenPreparation" do
      stub(Ash.Resource.Info, :action, fn _resource, _action_name ->
        %{
          preparations: [
            %Ash.Resource.Preparation{
              preparation:
                {RememberMe.MaybeGenerateTokenPreparation, [argument: :custom_remember]}
            }
          ],
          changes: []
        }
      end)

      strategy = %{resource: Example.Accounts.User, sign_in_action_name: :sign_in}

      assert Helpers.remember_me_field(strategy) == :custom_remember
    end

    test "returns default :remember_me when preparation has no argument option" do
      stub(Ash.Resource.Info, :action, fn _resource, _action_name ->
        %{
          preparations: [
            %Ash.Resource.Preparation{
              preparation: {RememberMe.MaybeGenerateTokenPreparation, []}
            }
          ],
          changes: []
        }
      end)

      strategy = %{resource: Example.Accounts.User, sign_in_action_name: :sign_in}

      assert Helpers.remember_me_field(strategy) == :remember_me
    end

    test "returns field name from MaybeGenerateTokenChange in changes" do
      stub(Ash.Resource.Info, :action, fn _resource, _action_name ->
        %{
          preparations: [],
          changes: [
            %Ash.Resource.Change{
              change: {RememberMe.MaybeGenerateTokenChange, [argument: :remember_me]}
            }
          ]
        }
      end)

      strategy = %{resource: Example.Accounts.User, sign_in_action_name: :sign_in}

      assert Helpers.remember_me_field(strategy) == :remember_me
    end

    test "returns custom field name from MaybeGenerateTokenChange" do
      stub(Ash.Resource.Info, :action, fn _resource, _action_name ->
        %{
          preparations: [],
          changes: [
            %Ash.Resource.Change{
              change: {RememberMe.MaybeGenerateTokenChange, [argument: :custom_remember]}
            }
          ]
        }
      end)

      strategy = %{resource: Example.Accounts.User, sign_in_action_name: :sign_in}

      assert Helpers.remember_me_field(strategy) == :custom_remember
    end

    test "returns default :remember_me when change has no argument option" do
      stub(Ash.Resource.Info, :action, fn _resource, _action_name ->
        %{
          preparations: [],
          changes: [
            %Ash.Resource.Change{
              change: {RememberMe.MaybeGenerateTokenChange, []}
            }
          ]
        }
      end)

      strategy = %{resource: Example.Accounts.User, sign_in_action_name: :sign_in}

      assert Helpers.remember_me_field(strategy) == :remember_me
    end

    test "prefers preparation over change when both exist" do
      stub(Ash.Resource.Info, :action, fn _resource, _action_name ->
        %{
          preparations: [
            %Ash.Resource.Preparation{
              preparation:
                {RememberMe.MaybeGenerateTokenPreparation, [argument: :from_preparation]}
            }
          ],
          changes: [
            %Ash.Resource.Change{
              change: {RememberMe.MaybeGenerateTokenChange, [argument: :from_change]}
            }
          ]
        }
      end)

      strategy = %{resource: Example.Accounts.User, sign_in_action_name: :sign_in}

      assert Helpers.remember_me_field(strategy) == :from_preparation
    end

    test "ignores unrelated preparations and changes" do
      stub(Ash.Resource.Info, :action, fn _resource, _action_name ->
        %{
          preparations: [
            %Ash.Resource.Preparation{
              preparation: {SomeOtherModule, []}
            }
          ],
          changes: [
            %Ash.Resource.Change{
              change: {AnotherModule, [argument: :something]}
            },
            %Ash.Resource.Change{
              change: {RememberMe.MaybeGenerateTokenChange, [argument: :remember_me]}
            }
          ]
        }
      end)

      strategy = %{resource: Example.Accounts.User, sign_in_action_name: :sign_in}

      assert Helpers.remember_me_field(strategy) == :remember_me
    end
  end
end
