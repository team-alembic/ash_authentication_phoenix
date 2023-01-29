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

  use AshAuthentication.Phoenix.StrategyComponent,
    visual_style: :link,
    strategies: [AshAuthentication.Strategy.OAuth2]

  alias AshAuthentication.Info
  alias Phoenix.LiveView.Rendered
  import AshAuthentication.Phoenix.Components.Helpers, only: [route_helpers: 1]
  import Phoenix.HTML
  import Phoenix.HTML.Form, only: [humanize: 1]

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          optional(:overrides) => [module]
        }

  @doc false
  @impl true
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

  defp icon_svg(:github, class),
    do: ~s"""
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="#{class}">
    <path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22">
    </path>
    </svg>
    """

  defp strategy_name(strategy) do
    case strategy.name do
      :oauth2 -> "OAuth"
      other -> humanize(other)
    end
  end
end
