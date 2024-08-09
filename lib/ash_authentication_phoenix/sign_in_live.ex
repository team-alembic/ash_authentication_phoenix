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
      |> assign(:path, session["path"] || "/")
      |> assign(:reset_path, session["reset_path"])
      |> assign(:register_path, session["register_path"])
      |> assign(:current_tenant, session["tenant"])
      |> assign(:context, session["context"] || %{})
      |> assign(:auth_routes_prefix, session["auth_routes_prefix"])

    {:ok, socket}
  end

  @impl true
  def handle_params(_, _uri, socket) do
    {:noreply, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t()
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <.live_component
        module={Components.SignIn}
        otp_app={@otp_app}
        live_action={@live_action}
        path={@path}
        auth_routes_prefix={@auth_routes_prefix}
        reset_path={@reset_path}
        register_path={@register_path}
        id={override_for(@overrides, :sign_in_id, "sign-in")}
        overrides={@overrides}
        current_tenant={@current_tenant}
        context={@context}
      />
    </div>
    """
  end
end
