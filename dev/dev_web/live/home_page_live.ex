# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule DevWeb.HomePageLive do
  @moduledoc false
  use Phoenix.LiveView
  alias DevWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView.{Rendered, Socket}

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    # Each authenticated resource gets its own assign, named after its
    # subject: current_user, current_admin, current_anon_user.
    assigns =
      assigns
      |> assign_new(:current_user, fn -> nil end)
      |> assign_new(:current_admin, fn -> nil end)
      |> assign_new(:current_anon_user, fn -> nil end)

    ~H"""
    <%= if @current_user || @current_admin || @current_anon_user do %>
      <%= if @current_user do %>
        <h2>Current user: {@current_user.email}</h2>
        <ul>
          <li><.link navigate="/webauthn-setup">Manage passkeys (add a credential)</.link></li>
          <li><.link navigate="/webauthn-verify">Verify with a passkey (WebAuthn 2FA)</.link></li>
        </ul>
      <% end %>
      <%= if @current_admin do %>
        <h2>Current admin: {@current_admin.email}</h2>
      <% end %>
      <%= if @current_anon_user do %>
        <h2>Current anonymous user: {@current_anon_user.id}</h2>
        <ul>
          <li><.link navigate="/passkey-setup">Manage passkeys (add a credential)</.link></li>
        </ul>
      <% end %>

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
