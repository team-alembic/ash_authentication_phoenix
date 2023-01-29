defmodule AshAuthentication.Phoenix.SignInLive do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    sign_in_id: "Element ID for the `SignIn` LiveComponent."

  @moduledoc """
  A generic, white-label sign-in page.

  This live-view can be rendered into your app using the
  `AshAuthentication.Phoenix.Router.sign_in_route/1` macro in your router (or by
  using `Phoenix.LiveView.Controller.live_render/3` directly in your markup).

  This live-view finds all Ash resources with an authentication configuration
  (via `AshAuthentication.authenticated_resources/1`) and renders the
  appropriate UI for their providers using
  `AshAuthentication.Phoenix.Components.SignIn`.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use Phoenix.LiveView
  alias AshAuthentication.Phoenix.Components
  alias Phoenix.LiveView.{Rendered, Socket}

  @default_strategy_components [
    AshAuthentication.Phoenix.Components.Password,
    AshAuthentication.Phoenix.Components.OAuth2
  ]

  @default_overrides [AshAuthentication.Phoenix.Overrides.Default]

  @doc false
  @impl true
  def mount(_params, session, socket) do
    overrides = Map.get(session, "overrides") || @default_overrides
    strategy_components = Map.get(session, "strategy_components") || @default_strategy_components

    socket =
      socket
      |> assign(overrides: overrides, strategy_components: strategy_components)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t()
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <.live_component
        module={Components.SignIn}
        id={override_for(@overrides, :sign_in_id, "sign-in")}
        overrides={@overrides}
        strategy_components={@strategy_components}
      />
    </div>
    """
  end
end
