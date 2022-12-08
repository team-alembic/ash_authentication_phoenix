defmodule AshAuthentication.Phoenix.SignInLive do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    sign_in_id: "Element ID for the `SignIn` LiveComponent."

  @moduledoc """
  A generic, white-label sign-in page.

  This live-view can be rendered into your app by using the
  `AshAuthentication.Phoenix.Router.sign_in_route/3` macro in your router (or by
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

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t()
  def render(assigns) do
    ~H"""
    <div class={override_for(@socket, :root_class)}>
      <.live_component module={Components.SignIn} id={override_for(@socket, :sign_in_id, "sign-in")} />
    </div>
    """
  end
end
