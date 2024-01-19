defmodule DevWeb do
  @moduledoc false

  # The entrypoint for defining your web interface, such
  # as controllers, views, channels and so on.

  # This can be used in your application as:

  #     use DevWeb, :controller
  #     use DevWeb, :view

  # The definitions below will be executed for every view,
  # controller, etc, so keep them short and clean, focused
  # on imports, uses and aliases.

  # Do NOT define functions inside the quoted expressions
  # below. Instead, define any helper function in modules
  # and import those modules here.

  @doc false
  def controller do
    quote do
      use Phoenix.Controller, namespace: DevWeb

      import Plug.Conn
      alias DevWeb.Router.Helpers, as: Routes
    end
  end

  @doc false
  def view do
    quote do
      use Phoenix.View,
        root: "dev/dev_web/templates",
        namespace: DevWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  @doc false
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {DevWeb.LayoutView, "live.html"}

      unquote(view_helpers())
    end
  end

  @doc false
  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  @doc false
  def component do
    quote do
      use Phoenix.Component

      unquote(view_helpers())
    end
  end

  @doc false
  def router do
    quote do
      use Phoenix.Router, helpers_moduledoc: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  @doc false
  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      import Phoenix.HTML
      import Phoenix.HTML.Form
      use PhoenixHTMLHelpers
      use Phoenix.Component

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import DevWeb.ErrorHelpers
      alias DevWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
