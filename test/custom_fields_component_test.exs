# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.CustomFieldsComponentTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Ash.Resource.Info
  alias AshAuthentication.Phoenix.Components.CustomFields

  defmodule TypeOverrides do
    @moduledoc false
    use AshAuthentication.Phoenix.Overrides

    override CustomFields do
      set :field_input_types, %{personal_number: :password}
    end
  end

  defp render_field(field_name, assigns \\ []) do
    form =
      Example.Accounts.User
      |> AshPhoenix.Form.for_action(:register_with_password,
        domain: Example.Accounts,
        as: "user"
      )
      |> Phoenix.Component.to_form()

    render_component(
      &CustomFields.field/1,
      Keyword.merge(
        [
          form: form,
          attribute: Info.attribute(Example.Accounts.User, field_name),
          overrides: [AshAuthentication.Phoenix.Overrides.Default]
        ],
        assigns
      )
    )
  end

  describe "field/1" do
    test "renders a text input with mirrored constraints for a plain string attribute" do
      html = render_field(:name)

      assert html =~ ~s(type="text")
      assert html =~ ~s(name="user[name]")
      assert html =~ ~s(minlength="2")
      refute html =~ ~s(required)
    end

    test "does not mask sensitive attributes confirmed with secret?: false" do
      html = render_field(:personal_number, secret?: false)

      assert html =~ ~s(type="text")
    end

    test "masks fields confirmed with secret?: true" do
      html = render_field(:personal_number, secret?: true)

      assert html =~ ~s(type="password")
    end

    test "asks for a secret? confirmation when a sensitive attribute lacks one" do
      error = assert_raise ArgumentError, fn -> render_field(:personal_number) end

      assert error.message =~ "sensitive?: true"
      assert error.message =~ "personal_number: [secret?: false]"
    end

    test "field_input_types override forces the input type and counts as confirmation" do
      html =
        render_field(:personal_number,
          overrides: [TypeOverrides, AshAuthentication.Phoenix.Overrides.Default]
        )

      assert html =~ ~s(type="password")
    end
  end
end
