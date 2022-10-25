defmodule DevWeb.PageController do
  @moduledoc false

  use DevWeb, :controller
  alias Plug.Conn

  @doc false
  @spec index(Conn.t(), %{required(String.t()) => String.t()}) :: Conn.t()
  def index(conn, _params) do
    render(conn, "index.html")
  end
end
