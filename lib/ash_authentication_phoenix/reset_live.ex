defmodule AshAuthentication.Phoenix.ResetLive do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    reset_id: "Element ID for the `Reset` LiveComponent."

  @moduledoc """
  A generic, white-label password reset page.

  This live-view can be rendered into your app using the
  `AshAuthentication.Phoenix.Router.reset_route/1` macro in your router (or by
  using `Phoenix.LiveView.Controller.live_render/3` directly in your markup).

  This live-view looks for the `token` URL parameter, and if found passes it to
  `AshAuthentication.Phoenix.Components.Reset`.

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
      |> assign(:current_tenant, session["tenant"])
      |> assign(:context, session["context"] || %{})
      |> assign(:auth_routes_prefix, session["auth_routes_prefix"])

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec handle_params(map, String.t(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_params(%{"token" => token}, _uri, socket) do
    {:noreply, assign(socket, :token, token)}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t()
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <.live_component
        module={Components.Reset}
        otp_app={@otp_app}
        id={override_for(@overrides, :reset_id, "reset")}
        token={@token}
        auth_routes_prefix={@auth_routes_prefix}
        overrides={@overrides}
        current_tenant={@current_tenant}
        context={@context}
      />
    </div>
    """
  end
end
