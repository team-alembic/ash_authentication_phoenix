defmodule AshAuthentication.Phoenix.Components.Apple do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS classes for the root `div` element.",
    link_class: "CSS classes for the `a` element.",
    icon_class: "CSS classes for the icon SVG."

  @moduledoc """
  Generates a sign-in button for Apple.

  ## Component hierarchy

  This is the top-most strategy-specific component, nested below
  `AshAuthentication.Phoenix.Components.SignIn`.

  ## Props

    * `strategy` - The strategy configuration as per
      `AshAuthentication.Info.strategy/2`.  Required.
    * `overrides` - A list of override modules.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Strategy}
  alias Phoenix.LiveView.Rendered
  import AshAuthentication.Phoenix.Components.Helpers, only: [route_helpers: 1]
  import Phoenix.HTML, only: [raw: 1]

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
            {@subject_name, Strategy.name(@strategy), :request}
          )
        }
        class={override_for(@overrides, :link_class)}
      >
        <.icon icon={:apple_white} overrides={@overrides} />
        <.icon icon={:apple_black} overrides={@overrides} /> Sign in with Apple
      </a>
    </div>
    """
  end

  def icon(assigns) do
    ~H"""
    <%= raw(icon_svg(@icon, override_for(@overrides, :icon_class))) %>
    """
  end

  defp icon_svg(:apple_white, class),
    do: ~s"""
    <svg width="24px" height="44px" viewBox="0 0 24 44" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" class="#{class} inline-block dark:hidden">
        <!-- Generator: Sketch 61 (89581) - https://sketch.com -->
        <title>Left White Logo Small</title>
        <desc>Created with Sketch.</desc>
        <g id="Left-White-Logo-Small" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
            <rect id="Rectangle" fill="#000000" x="0" y="0" width="24" height="44"></rect>
            <path d="M12.2337427,16.9879688 C12.8896607,16.9879688 13.7118677,16.5445313 14.2014966,15.9532812 C14.6449341,15.4174609 14.968274,14.6691602 14.968274,13.9208594 C14.968274,13.8192383 14.9590357,13.7176172 14.9405591,13.6344727 C14.2107349,13.6621875 13.3330982,14.1241016 12.8065162,14.7430664 C12.3907935,15.2142188 12.012024,15.9532812 12.012024,16.7108203 C12.012024,16.8216797 12.0305005,16.9325391 12.0397388,16.9694922 C12.0859302,16.9787305 12.1598365,16.9879688 12.2337427,16.9879688 Z M9.92417241,28.1662891 C10.8202857,28.1662891 11.2175318,27.5658008 12.3353638,27.5658008 C13.4716724,27.5658008 13.721106,28.1478125 14.7188404,28.1478125 C15.6980982,28.1478125 16.3540162,27.2424609 16.972981,26.3555859 C17.6658521,25.339375 17.9522388,24.3416406 17.9707154,24.2954492 C17.9060474,24.2769727 16.0306763,23.5101953 16.0306763,21.3576758 C16.0306763,19.491543 17.5088013,18.6508594 17.5919459,18.5861914 C16.612688,17.1819727 15.1253248,17.1450195 14.7188404,17.1450195 C13.6194849,17.1450195 12.7233716,17.8101758 12.1598365,17.8101758 C11.5501099,17.8101758 10.7463794,17.1819727 9.79483648,17.1819727 C7.98413335,17.1819727 6.14571538,18.6785742 6.14571538,21.5054883 C6.14571538,23.2607617 6.8293482,25.1176563 7.67003179,26.3186328 C8.39061773,27.3348438 9.01882085,28.1662891 9.92417241,28.1662891 Z" id="" fill="#FFFFFF" fill-rule="nonzero"></path>
        </g>
    </svg>
    """

  defp icon_svg(:apple_black, class),
    do: ~s"""
    <svg width="24px" height="44px" viewBox="0 0 24 44" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" class="#{class} hidden dark:inline-block">
        <!-- Generator: Sketch 61 (89581) - https://sketch.com -->
        <title>Left Black Logo Small</title>
        <desc>Created with Sketch.</desc>
        <g id="Left-Black-Logo-Small" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
            <rect id="Rectangle" fill="#FFFFFF" x="0" y="0" width="24" height="44"></rect>
            <path d="M12.2337427,16.9879688 C12.8896607,16.9879688 13.7118677,16.5445313 14.2014966,15.9532812 C14.6449341,15.4174609 14.968274,14.6691602 14.968274,13.9208594 C14.968274,13.8192383 14.9590357,13.7176172 14.9405591,13.6344727 C14.2107349,13.6621875 13.3330982,14.1241016 12.8065162,14.7430664 C12.3907935,15.2142188 12.012024,15.9532812 12.012024,16.7108203 C12.012024,16.8216797 12.0305005,16.9325391 12.0397388,16.9694922 C12.0859302,16.9787305 12.1598365,16.9879688 12.2337427,16.9879688 Z M9.92417241,28.1662891 C10.8202857,28.1662891 11.2175318,27.5658008 12.3353638,27.5658008 C13.4716724,27.5658008 13.721106,28.1478125 14.7188404,28.1478125 C15.6980982,28.1478125 16.3540162,27.2424609 16.972981,26.3555859 C17.6658521,25.339375 17.9522388,24.3416406 17.9707154,24.2954492 C17.9060474,24.2769727 16.0306763,23.5101953 16.0306763,21.3576758 C16.0306763,19.491543 17.5088013,18.6508594 17.5919459,18.5861914 C16.612688,17.1819727 15.1253248,17.1450195 14.7188404,17.1450195 C13.6194849,17.1450195 12.7233716,17.8101758 12.1598365,17.8101758 C11.5501099,17.8101758 10.7463794,17.1819727 9.79483648,17.1819727 C7.98413335,17.1819727 6.14571538,18.6785742 6.14571538,21.5054883 C6.14571538,23.2607617 6.8293482,25.1176563 7.67003179,26.3186328 C8.39061773,27.3348438 9.01882085,28.1662891 9.92417241,28.1662891 Z" id="" fill="#000000" fill-rule="nonzero"></path>
        </g>
    </svg>
    """
end
