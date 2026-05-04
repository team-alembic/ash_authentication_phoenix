# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.DynamicOidcTest do
  @moduledoc false

  use ExUnit.Case, async: false
  import Phoenix.LiveViewTest

  alias AshAuthentication.Info
  alias AshAuthentication.Phoenix.Components.DynamicOidc
  alias Example.Accounts.OidcConnection

  setup do
    # ETS resource state persists across tests; clean it before each.
    Ash.bulk_destroy!(Ash.Query.new(OidcConnection), :destroy, %{})

    {:ok, acme} =
      OidcConnection
      |> Ash.Changeset.for_create(:create, %{
        base_url: "https://acme.okta.com/oauth2/default",
        client_id: "acme-id",
        client_secret: "acme-secret",
        display_name: "Acme Corp",
        icon_url: nil
      })
      |> Ash.create()

    {:ok, contoso} =
      OidcConnection
      |> Ash.Changeset.for_create(:create, %{
        base_url: "https://contoso.example.com/oauth2/default",
        client_id: "contoso-id",
        client_secret: "contoso-secret",
        display_name: nil,
        icon_url: "/contoso.svg"
      })
      |> Ash.create()

    %{acme: acme, contoso: contoso}
  end

  describe "render/1" do
    test "renders one button per connection row", %{acme: acme, contoso: contoso} do
      strategy = Info.strategy!(Example.Accounts.User, :sso)

      html =
        render_component(DynamicOidc, %{
          strategy: strategy,
          auth_routes_prefix: "/auth"
        })

      # Each connection produces an anchor with the connection_id in the
      # request path and a button label.
      assert html =~ "/auth/user/sso/#{acme.id}/request"
      assert html =~ "/auth/user/sso/#{contoso.id}/request"
      assert html =~ "Sign in with Acme Corp"
    end

    test "falls back to base_url's host when display_name is nil", %{contoso: contoso} do
      strategy = Info.strategy!(Example.Accounts.User, :sso)

      html =
        render_component(DynamicOidc, %{
          strategy: strategy,
          auth_routes_prefix: "/auth"
        })

      assert html =~ "Sign in with contoso.example.com"
      assert html =~ "/auth/user/sso/#{contoso.id}/request"
    end

    test "uses connection's icon_url when present" do
      strategy = Info.strategy!(Example.Accounts.User, :sso)

      html =
        render_component(DynamicOidc, %{
          strategy: strategy,
          auth_routes_prefix: "/auth"
        })

      assert html =~ ~s(src="/contoso.svg")
    end

    test "renders a default SVG icon when icon_url is nil" do
      strategy = Info.strategy!(Example.Accounts.User, :sso)

      html =
        render_component(DynamicOidc, %{
          strategy: strategy,
          auth_routes_prefix: "/auth"
        })

      # The Acme connection has icon_url: nil — should render the
      # generic SSO SVG fallback.
      assert html =~ "<svg"
    end

    test "renders nothing when no connections exist for the current tenant" do
      Ash.bulk_destroy!(Ash.Query.new(OidcConnection), :destroy, %{})

      strategy = Info.strategy!(Example.Accounts.User, :sso)

      html =
        render_component(DynamicOidc, %{
          strategy: strategy,
          auth_routes_prefix: "/auth"
        })

      refute html =~ "Sign in with"
    end
  end
end
