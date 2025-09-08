defmodule AshAuthentication.Phoenix.Components.OAuth2Test do
  @moduledoc false

  use ExUnit.Case, async: false
  import Phoenix.LiveViewTest

  alias Gettext.Interpolation.Default
  alias AshAuthentication.Phoenix.Components.OAuth2
  alias AshAuthentication.Phoenix.Overrides.Default
  alias AshAuthentication.Info

  describe "icon_src override" do
    defmodule TestOverridesWithIconSrc do
      use AshAuthentication.Phoenix.Overrides

      override AshAuthentication.Phoenix.Components.OAuth2 do
        set :icon_src, %{twitch: "/twitch-icon.svg"}
        set :icon_class, "-ml-0.4 mr-2 h-4 w-4"
        set :root_class, "w-full"
        set :link_class, "btn"
      end
    end

    test "renders custom icon source when icon_src override is provided" do
      strategy = Info.strategy!(Example.Accounts.User, :twitch)

      assigns = %{
        strategy: strategy,
        overrides: [TestOverridesWithIconSrc],
        auth_routes_prefix: "/auth"
      }

      html = render_component(OAuth2, assigns)

      assert html =~ ~s(<img src="/twitch-icon.svg")
      assert html =~ ~s(class="-ml-0.4 mr-2 h-4 w-4")
      refute html =~ "<svg"
    end

    test "falls back to default SVG icon when icon_src override is not provided" do
      strategy = Info.strategy!(Example.Accounts.User, :twitch)

      assigns = %{
        strategy: strategy,
        overrides: [Default],
        auth_routes_prefix: "/auth"
      }

      html = render_component(OAuth2, assigns)

      refute html =~ "<img"
      assert html =~ "<svg"
    end
  end
end
