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

  ## Props

      * `overrides` - A list of override modules.
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
      <div class={override_for(@overrides, :hr_outer_class)} aria-hidden="true">
        <div class={override_for(@overrides, :hr_inner_class)}></div>
      </div>
      <div class={override_for(@overrides, :text_outer_class)}>
        <span class={override_for(@overrides, :text_inner_class)}>
          <%= override_for(@overrides, :text) %>
        </span>
      </div>
    </div>
    """
  end
end
