# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Banner do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    href_class: "CSS class for the `a` tag.",
    href_url: "A URL for the banner image to link to. Set to `nil` to disable.",
    image_class: "CSS class for the `img` tag.",
    dark_image_class: "Css class for the `img` tag in dark mode.",
    image_url: "A URL for the `img` `src` attribute. Set to `nil` to disable.",
    dark_image_url: "A URL for the `img` `src` attribute in dark mode. Set to `nil` to disable.",
    text_class: "CSS class for the text `div`.",
    text: "Banner text. Set to `nil` to disable."

  @moduledoc """
  Renders a very simple banner at the top of the sign-in component.

  Can show either an image or some text, depending on the provided overrides.

  ## Props

    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias Phoenix.LiveView.Rendered

  @type props :: %{
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }

  @doc false
  @impl true
  @spec render(props) :: Rendered.t() | no_return
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)

    image_url = override_for(assigns.overrides, :image_url)
    raw_dark_image_url = override_for(assigns.overrides, :dark_image_url)
    # When image_url is set to nil, also suppress dark_image_url.
    # This ensures setting image_url: nil disables both light and dark mode images,
    # matching user expectations that nil means "no image".
    dark_image_url = if is_nil(image_url), do: nil, else: raw_dark_image_url

    assigns =
      assigns
      |> assign(:image_url, image_url)
      |> assign(:dark_image_url, dark_image_url)

    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= case {override_for(@overrides, :href_url), @image_url} do %>
        <% {_, nil} -> %>
        <% {nil, img} -> %>
          <img class={override_for(@overrides, :image_class)} src={img} />
        <% {hrf, img} -> %>
          <a class={override_for(@overrides, :href_class)} href={hrf}>
            <img class={override_for(@overrides, :image_class)} src={img} />
          </a>
      <% end %>
      <%= case {override_for(@overrides, :href_url), @dark_image_url} do %>
        <% {_, nil} -> %>
        <% {nil, img} -> %>
          <img class={override_for(@overrides, :dark_image_class)} src={img} />
        <% {hrf, img} -> %>
          <a class={override_for(@overrides, :href_class)} href={hrf}>
            <img class={override_for(@overrides, :dark_image_class)} src={img} />
          </a>
      <% end %>
      <%= case  {override_for(@overrides, :href_url), override_for(@overrides, :text)} do %>
        <% {_, nil} -> %>
        <% {nil, txt} -> %>
          <div class={override_for(@overrides, :text_class)}>
            {_gettext(txt)}
          </div>
        <% {hrf, txt} -> %>
          <div class={override_for(@overrides, :text_class)}>
            <a class={override_for(@overrides, :href_class)} href={hrf}>
              {_gettext(txt)}
            </a>
          </div>
      <% end %>
    </div>
    """
  end
end
