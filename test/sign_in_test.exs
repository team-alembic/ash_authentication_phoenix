defmodule AshAuthentication.Phoenix.SignInTest do
  @moduledoc false
  use ExUnit.Case
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint AshAuthentication.Phoenix.Test.Endpoint

  setup do
    # foo
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  test "sign_in routes liveview renders the sign in page", %{conn: conn} do
    conn = get(conn, "/sign-in")
    assert {:ok, _view, html} = live(conn)
    assert html =~ "Sign in"
  end
end
