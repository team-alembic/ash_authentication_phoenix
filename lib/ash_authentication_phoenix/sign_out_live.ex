# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.SignOutLive do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element."

  @moduledoc """
  A generic, white-label sign-out confirmation page.

  This live-view can be rendered into your app using the
  `AshAuthentication.Phoenix.Router.sign_out_route/3` macro in your router.

  It displays a confirmation form that submits a DELETE request to the sign-out
  controller action, ensuring CSRF protection.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_view
  alias AshAuthentication.Phoenix.Components
  alias Phoenix.LiveView.{Rendered, Socket}

  @doc false
  @impl true
  def mount(_params, session, socket) do
    overrides =
      session
      |> Map.get("overrides", [AshAuthentication.Phoenix.Overrides.Default])

    socket =
      socket
      |> assign(overrides: overrides)
      |> assign_new(:otp_app, fn -> nil end)
      |> assign(:sign_out_path, session["sign_out_path"] || "/sign-out")
      |> assign(:gettext_fn, session["gettext_fn"])

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t()
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <.live_component
        module={Components.SignOut}
        id="sign-out"
        overrides={@overrides}
        sign_out_path={@sign_out_path}
      />
    </div>
    """
  end
end
