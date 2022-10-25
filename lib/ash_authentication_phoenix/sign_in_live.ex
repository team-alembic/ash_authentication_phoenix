defmodule AshAuthentication.Phoenix.SignInLive do
  @moduledoc """
  A generic, white-label sign-in page.

  This live-view can be rendered into your app by using the
  `AshAuthentication.Phoenix.Router.sign_in_route/3` macro in your router (or by
  using `Phoenix.LiveView.Controller.live_render/3` directly in your markup).

  This live-view finds all Ash resources with an authentication configuration
  (via `AshAuthentication.authenticated_resources/1`) and renders the
  appropriate UI for their providers using
  `AshAuthentication.Phoenix.Components.SignIn`.

  ## Overrides

  See `AshAuthentication.Phoenix.Overrides` for more information.

    * `sign_in_live_css_class` - applied to the root `div` element of this
      liveview.
  """

  use Phoenix.LiveView
  alias AshAuthentication.Phoenix.Components
  alias Phoenix.LiveView.{Rendered, Socket}
  import Components.Helpers

  @doc false
  @impl true
  @spec mount(map, map, Socket.t()) :: {:ok, Socket.t()}
  def mount(_params, _, socket) do
    resources =
      socket
      |> otp_app_from_socket()
      |> AshAuthentication.authenticated_resources()
      |> Enum.group_by(& &1.subject_name)
      |> Enum.sort_by(&elem(&1, 0))

    socket =
      socket
      |> assign(:resources, resources)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t()
  def render(assigns) do
    ~H"""
    <div class={override_for(@socket, :sign_in_live_css_class)}>
      <%= for {subject_name, configs} <- @resources do %>
        <%= for config <- configs do %>
          <.live_component module={Components.SignIn} id={"sign-in-#{subject_name}"} config={config} />
        <% end %>
      <% end %>
    </div>
    """
  end
end
