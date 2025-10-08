# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Test.ComponentsLive do
  @moduledoc false
  use Phoenix.LiveView, layout: {AshAuthentication.Phoenix.Test.HomeLive, :live}
  alias AshAuthentication.Phoenix.Components

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:auth_routes_prefix, session["auth_routes_prefix"])

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Sign-in component with minimal attributes --%>
    <.live_component module={Components.SignIn} id="sign-in" auth_routes_prefix={@auth_routes_prefix} />
    """
  end
end
