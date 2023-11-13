defmodule AshAuthentication.Phoenix.Components.Banner do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    href_class: "CSS class for the `a` tag.",
    href_url: "A URL for the banner image to link to. Set to `nil` to disable.",
    image_class: "CSS class for the `img` tag.",
    dark_image_class: "Css class for the `img` tag in dark mode.",
    image_url: "A URL for the `img` `src` attribute. Set to `nil` to disable.",
    dark_image_url: "A URL for the `img` `src` attribute in dark mode. Set to `nil` to disable.",
    image_class: "CSS class for the `img` tag in dark mode.",
    text_class: "CSS class for the text `div`.",
    text: "Banner text. Set to `nil` to disable."

  @moduledoc """
  Renders a very simple banner at the top of the sign-in component.

  Can show either an image or some text, depending on the provided overrides.

  ## Props

    * `overrides` - A list of override modules.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias Phoenix.LiveView.Rendered

  @type props :: %{
          optional(:overrides) => [module]
        }

  @doc false
  @impl true
  @spec render(props) :: Rendered.t() | no_return
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)

    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= case {override_for(@overrides, :href_url), override_for(@overrides, :image_url)} do %>
        <% {nil, nil} -> %>
        <% {nil, img} -> %>
          <img class={override_for(@overrides, :image_class)} src={img} />
        <% {hrf, img} -> %>
          <a class={override_for(@overrides, :href_class)} href={hrf}>
            <img class={override_for(@overrides, :image_class)} src={img} />
          </a>
      <% end %>
      <%= case {override_for(@overrides, :href_url), override_for(@overrides, :dark_image_url)} do %>
        <% {nil, nil} -> %>
        <% {nil, img} -> %>
          <img class={override_for(@overrides, :dark_image_class)} src={img} />
        <% {hrf, img} -> %>
          <a class={override_for(@overrides, :href_class)} href={hrf}>
            <img class={override_for(@overrides, :dark_image_class)} src={img} />
          </a>
      <% end %>
      <%= case  {override_for(@overrides, :href_url), override_for(@overrides, :text)} do %>
        <% {nil, nil} -> %>
        <% {nil, txt} -> %>
          <div class={override_for(@overrides, :text_class)}>
            <%= txt %>
          </div>
        <% {hrf, txt} -> %>
          <div class={override_for(@overrides, :text_class)}>
            <a class={override_for(@overrides, :href_class)} href={hrf}>
              <%= txt %>
            </a>
          </div>
      <% end %>
    </div>
    """
  end
end
