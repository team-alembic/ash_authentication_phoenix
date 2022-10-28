defmodule AshAuthentication.Phoenix.Components.Banner do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    href_class: "CSS class for the `a` tag.",
    href_url: "A URL for the banner image to link to.",
    image_class: "CSS class for the `img` tag.",
    image_url: "A URL for the `img` `src` attribute.",
    text_class: "CSS class for the text `div`.",
    text: "Banner text"

  @moduledoc """
  Renders a very simple banner at the top of the sign-in component.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use Phoenix.LiveComponent
  alias Phoenix.LiveView.{Rendered, Socket}

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@socket, :root_class)}>
      <%= case {override_for(@socket, :href_url), override_for(@socket, :image_url)} do %>
        <% {nil, img} -> %>
          <img class={override_for(@socket, :image_class)} src={img} />
        <% {hrf, img} -> %>
          <a class={override_for(@socket, :href_class)} href={hrf}>
            <img class={override_for(@socket, :image_class)} src={img} />
          </a>
      <% end %>
      <%= case  override_for(@socket, :text) do %>
        <% text when is_binary(text) -> %>
          <div class={override_for(@socket, :text_class)}>
            <%= text %>
          </div>
        <% _ -> %>
      <% end %>
    </div>
    """
  end
end
