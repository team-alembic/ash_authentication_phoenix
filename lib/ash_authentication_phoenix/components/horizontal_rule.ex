defmodule AshAuthentication.Phoenix.Components.HorizontalRule do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    hr_outer_class: "CSS class for the outer `div` element of the horizontal rule.",
    hr_inner_class: "CSS class for the inner `div` element of the horizontal rule.",
    text_outer_class: "CSS class for the outer `div` element of the text area.",
    text_inner_class: "CSS class for the inner `div` element of the text area.",
    text: "Text to display in front of the horizontal rule."

  @moduledoc """
  A horizontal rule with text.

  This component is pretty tailwind-specific, but I (@jimsynz) really wanted a
  certain look.  If you think I'm wrong then please let me know.

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
      <div class={override_for(@socket, :hr_outer_class)} aria-hidden="true">
        <div class={override_for(@socket, :hr_inner_class)}></div>
      </div>
      <div class={override_for(@socket, :text_outer_class)}>
        <span class={override_for(@socket, :text_inner_class)}>
          <%= override_for(@socket, :text) %>
        </span>
      </div>
    </div>
    """
  end
end
