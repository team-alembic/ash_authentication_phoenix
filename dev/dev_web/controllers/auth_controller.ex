defmodule DevWeb.AuthController do
  @moduledoc false

  use DevWeb, :controller
  use AshAuthentication.Phoenix.Controller

  @doc false
  @impl true
  def success(conn, _activity, user, _token) do
    conn
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> put_status(200)
    |> render("success.html")
  end

  @doc false
  @impl true
  def failure(conn, _activity, reason) do
    conn
    |> assign(:failure_reason, reason)
    |> redirect(to: "/sign-in")
  end

  @doc false
  @impl true
  def sign_out(conn, _params) do
    conn
    |> clear_session()
    |> render("sign_out.html")
  end
end
