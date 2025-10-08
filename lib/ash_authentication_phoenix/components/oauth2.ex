# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.OAuth2 do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS classes for the root `div` element.",
    link_class: "CSS classes for the `a` element.",
    icon_class: "CSS classes for the icon SVG.",
    icon_src: "Map of strategy names to icon sources."

  @moduledoc """
  Generates a sign-in button for OAuth2.

  ## Component hierarchy

  This is the top-most strategy-specific component, nested below
  `AshAuthentication.Phoenix.Components.SignIn`.

  ## Props

    * `strategy` - The strategy configuration as per
      `AshAuthentication.Info.strategy/2`.  Required.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Strategy}
  alias Phoenix.LiveView.Rendered
  import AshAuthentication.Phoenix.Components.Helpers, only: [auth_path: 5]
  import Phoenix.HTML, only: [raw: 1]
  import PhoenixHTMLHelpers.Form, only: [humanize: 1]

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          optional(:auth_routes_prefix) => String.t(),
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }

  @doc false
  @impl true
  @spec render(props) :: Rendered.t() | no_return
  def render(assigns) do
    strategy_name = assigns.strategy.name
    icon_src = override_for(assigns.overrides, :icon_src)[strategy_name]

    assigns =
      assigns
      |> assign(:subject_name, Info.authentication_subject_name!(assigns.strategy.resource))
      |> assign(:icon_src, icon_src)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)

    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <a
        href={auth_path(@socket, @subject_name, @auth_routes_prefix, @strategy, :request)}
        class={override_for(@overrides, :link_class)}
      >
        <.icon icon={@strategy.icon} overrides={@overrides} icon_src={@icon_src} />
        {_gettext("Sign in with #{strategy_name(@strategy)}")}
      </a>
    </div>
    """
  end

  def icon(assigns) do
    ~H"""
    <%= if @icon_src do %>
      <img src={@icon_src} class={override_for(@overrides, :icon_class)} alt="" />
    <% else %>
      <%= if @icon do %>
        {raw(icon_svg(@icon, override_for(@overrides, :icon_class)))}
      <% end %>
    <% end %>
    """
  end

  defp icon_svg(:google, class),
    do: ~s"""
    <svg class="#{class}" width="24" height="24" viewBox="11 9 22 22" fill="none" xmlns="http://www.w3.org/2000/svg">
    <g>
    <path d="M31.6 20.2273C31.6 19.5182 31.5364 18.8364 31.4182 18.1818H22V22.05H27.3818C27.15 23.3 26.4455 24.3591 25.3864 25.0682V27.5773H28.6182C30.5091 25.8364 31.6 23.2727 31.6 20.2273Z" fill="#4285F4"/>
    <path d="M22 30C24.7 30 26.9636 29.1045 28.6181 27.5773L25.3863 25.0682C24.4909 25.6682 23.3454 26.0227 22 26.0227C19.3954 26.0227 17.1909 24.2636 16.4045 21.9H13.0636V24.4909C14.7091 27.7591 18.0909 30 22 30Z" fill="#34A853"/>
    <path d="M16.4045 21.9C16.2045 21.3 16.0909 20.6591 16.0909 20C16.0909 19.3409 16.2045 18.7 16.4045 18.1V15.5091H13.0636C12.3864 16.8591 12 18.3864 12 20C12 21.6136 12.3864 23.1409 13.0636 24.4909L16.4045 21.9Z" fill="#FBBC04"/>
    <path d="M22 13.9773C23.4681 13.9773 24.7863 14.4818 25.8227 15.4727L28.6909 12.6045C26.9591 10.9909 24.6954 10 22 10C18.0909 10 14.7091 12.2409 13.0636 15.5091L16.4045 18.1C17.1909 15.7364 19.3954 13.9773 22 13.9773Z" fill="#E94235"/>
    </g>
    </svg>
    """

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

  defp icon_svg(:oidc, class),
    do: ~s"""
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="#{class}">
    <path d="m 75.180374,15.11293 -15.99577,7.797938 0,79.945522 C 40.931432,100.568 27.193065,90.619126 27.193065,78.662788 c 0,-11.334002 12.358733,-20.879977 29.192279,-23.793706 l 0,-10.163979 C 30.637155,47.81728 11.197296,61.839238 11.197296,78.662788 c 0,17.429891 20.856984,31.825422 47.987308,34.224282 l 15.99577,-7.53134 0,-90.2428 z m 2.79926,29.592173 0,10.163979 c 6.261409,1.083679 11.913385,3.061436 16.528961,5.731817 l -8.664375,4.898704 30.95849,6.731553 -2.23275,-22.927269 -8.23115,4.632108 C 98.692362,49.310409 88.899095,46.024898 77.979634,44.705103 z">
    </path>
    </svg>
    """

  defp icon_svg(:slack, class),
    do: ~s"""
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="#{class}">
    <path d="M14.5 10c-.83 0-1.5-.67-1.5-1.5v-5c0-.83.67-1.5 1.5-1.5s1.5.67 1.5 1.5v5c0 .83-.67 1.5-1.5 1.5z"></path>
    <path d="M20.5 10H19V8.5c0-.83.67-1.5 1.5-1.5s1.5.67 1.5 1.5-.67 1.5-1.5 1.5z"></path>
    <path d="M9.5 14c.83 0 1.5.67 1.5 1.5v5c0 .83-.67 1.5-1.5 1.5S8 21.33 8 20.5v-5c0-.83.67-1.5 1.5-1.5z"></path>
    <path d="M3.5 14H5v1.5c0 .83-.67 1.5-1.5 1.5S2 16.33 2 15.5 2.67 14 3.5 14z"></path>
    <path d="M14 14.5c0-.83.67-1.5 1.5-1.5h5c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5h-5c-.83 0-1.5-.67-1.5-1.5z"></path>
    <path d="M15.5 19H14v1.5c0 .83.67 1.5 1.5 1.5s1.5-.67 1.5-1.5-.67-1.5-1.5-1.5z"></path>
    <path d="M10 9.5C10 8.67 9.33 8 8.5 8h-5C2.67 8 2 8.67 2 9.5S2.67 11 3.5 11h5c.83 0 1.5-.67 1.5-1.5z"></path>
    <path d="M8.5 5H10V3.5C10 2.67 9.33 2 8.5 2S7 2.67 7 3.5 7.67 5 8.5 5z"></path>
    </svg>
    """

  defp icon_svg(_, class),
    do: ~s"""
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="#{class}">
      <rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect>
      <path d="M7 11V7a5 5 0 0 1 10 0v4"></path>
    </svg>
    """

  defp strategy_name(strategy) do
    case Strategy.name(strategy) do
      :oauth2 -> "OAuth"
      other -> humanize(other)
    end
  end
end
