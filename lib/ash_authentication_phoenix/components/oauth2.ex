defmodule AshAuthentication.Phoenix.Components.OAuth2 do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS classes for the root `div` element.",
    link_class: "CSS classes for the `a` element.",
    icon_class: "CSS classes for the icon SVG."

  @moduledoc """
  Generates a sign-in button for OAuth2.

  ## Component heirarchy

  This is the top-most provider specific component, nested below
  `AshAuthentication.Phoenix.Components.SignIn`.

  ## Props

    * `strategy` - The strategy configuration as per
      `AshAuthentication.Info.strategy/2`.  Required.
    * `overrides` - A list of override modules.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use Phoenix.LiveComponent
  alias AshAuthentication.Info
  alias Phoenix.LiveView.Rendered
  import AshAuthentication.Phoenix.Components.Helpers, only: [route_helpers: 1]
  import Phoenix.HTML
  import Phoenix.HTML.Form

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          optional(:overrides) => [module]
        }

  @doc false
  @spec render(props) :: Rendered.t() | no_return
  def render(assigns) do
    assigns =
      assigns
      |> assign(:subject_name, Info.authentication_subject_name!(assigns.strategy.resource))
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)

    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <a
        href={
          route_helpers(@socket).auth_path(
            @socket.endpoint,
            {@subject_name, @strategy.name, :request}
          )
        }
        class={override_for(@overrides, :link_class)}
      >
        <.icon icon={@strategy.icon} overrides={@overrides} />
        Sign in with <%= strategy_name(@strategy) %>
      </a>
    </div>
    """
  end

  def icon(assigns) do
    ~H"""
    <%= if @icon do %>
      <%= raw(icon_svg(@icon, override_for(@overrides, :icon_class))) %>
    <% end %>
    """
  end

  defp icon_svg(:auth0, class),
    do: ~s"""
    <svg class="#{class}" width="24" height="24" viewBox="0 0 41 45" fill="none" xmlns="http://www.w3.org/2000/svg">
    <g clip-path="url(#clip0)">
    <path d="M35.3018 0H20.5L25.0737 14.076H39.8755L27.9009 22.4701L32.4746 36.6253C40.1827 31.081 42.7027 22.6883 39.8755 14.076L35.3018 0Z" fill="currentColor"/>
    <path d="M1.12504 14.076H15.9268L20.5005 0H5.69875L1.12504 14.076C-1.70213 22.6898 0.8178 31.081 8.52592 36.6253L13.0996 22.4701L1.12504 14.076Z" fill="currentColor"/>
    <path d="M8.52539 36.6251L20.5 44.9998L32.4746 36.6251L20.5 28.1084L8.52539 36.6251Z" fill="currentColor"/>
    </g>
    <defs>
    <clipPath id="clip0">
    <rect width="41" height="45" fill="none"/>
    </clipPath>
    </defs>
    </svg>
    """

  defp strategy_name(strategy) do
    case strategy.name do
      :oauth2 -> "OAuth"
      other -> humanize(other)
    end
  end
end
