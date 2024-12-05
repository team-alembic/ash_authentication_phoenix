defmodule DevWeb.HomePageLive do
  @moduledoc false
  use Phoenix.LiveView
  alias DevWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView.{Rendered, Socket}

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    assigns = assign_new(assigns, :current_user, fn -> nil end)

    ~H"""
    <%= if @current_user do %>
      <h2>Current user: {@current_user.email}</h2>

      <.link navigate="/sign-out">Sign out</.link>
    <% else %>
      <h2>Please sign in</h2>

      <.link navigate="/sign-in">Standard sign in</.link>
      <br />
      <.link navigate={Routes.live_path(@socket, DevWeb.CustomSignInLive)}>Custom sign in</.link>
    <% end %>
    """
  end
end
