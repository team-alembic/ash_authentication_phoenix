defmodule DevWeb.PageController do
  @moduledoc false

  use DevWeb, :controller

  @doc false
  @impl true
  def index(conn, _params) do
    render(conn, "index.html")
  end
end
