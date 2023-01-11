defmodule DevWeb.HomePageLive do
  @moduledoc false
  use Phoenix.LiveView
  alias DevWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView.{Rendered, Socket}

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <%= if @current_user do %>
      <h2>Current user: <%= @current_user.email %></h2>

      <.link navigate={Routes.auth_path(@socket, :sign_out)}>Sign out</.link>
    <% else %>
      <h2>Please sign in</h2>

      <.link navigate={Routes.auth_path(@socket, :sign_in)}>Sign in</.link>
    <% end %>
    """
  end
end
