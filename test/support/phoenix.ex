defmodule AshAuthentication.Phoenix.Test.ErrorView do
  @moduledoc false
  @doc false
  def render(template, _), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule AshAuthentication.Phoenix.Test.HomeLive do
  @moduledoc false
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :count, 0)}
  end

  defp phx_vsn, do: Application.spec(:phoenix, :vsn)
  defp lv_vsn, do: Application.spec(:phoenix_live_view, :vsn)

  @doc false
  def render("live.html", assigns) do
    ~H"""
    <script src={"https://cdn.jsdelivr.net/npm/phoenix@#{phx_vsn()}/priv/static/phoenix.min.js"}>
    </script>
    <script
      src={"https://cdn.jsdelivr.net/npm/phoenix_live_view@#{lv_vsn()}/priv/static/phoenix_live_view.min.js"}
    >
    </script>
    <script>
      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket)
      liveSocket.connect()
    </script>
    <style>
      * { font-size: 1.1em; }
    </style>
    <%= @inner_content %>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= @count %>
    <button phx-click="inc">+</button>
    <button phx-click="dec">-</button>
    """
  end

  @impl true
  def handle_event("inc", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end

  def handle_event("dec", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count - 1)}
  end
end

defmodule AshAuthentication.Phoenix.Test.Router do
  @moduledoc false
  use Phoenix.Router
  import Phoenix.LiveView.Router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    plug :load_from_session
  end

  scope "/", AshAuthentication.Phoenix.Test do
    pipe_through :browser

    sign_in_route register_path: "/register", reset_path: "/reset", auth_routes_prefix: "/auth"
    sign_out_route AuthController
    reset_route []
    auth_routes AuthController, Example.Accounts.User, path: "/auth"
  end

  scope "/nested", AshAuthentication.Phoenix.Test do
    pipe_through :browser

    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  as: :nested

    sign_out_route AuthController
    reset_route as: :nested
  end

  scope "/unscoped", AshAuthentication.Phoenix.Test do
    pipe_through :browser

    sign_in_route register_path: {:unscoped, "/register"},
                  reset_path: {:unscoped, "/reset"},
                  auth_routes_prefix: {:unscoped, "/auth"},
                  as: :unscoped

    sign_out_route AuthController
    reset_route as: :unscoped
  end

  scope "/", AshAuthentication.Phoenix.Test do
    pipe_through(:browser)

    live("/", HomeLive, :index)
  end
end

defmodule AshAuthentication.Phoenix.Test.Endpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :ash_authentication_phoenix

  @session_options [
    store: :cookie,
    key: "_webuilt_key",
    signing_salt: "c911QDW5",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Session, @session_options
  plug(AshAuthentication.Phoenix.Test.Router)
end
