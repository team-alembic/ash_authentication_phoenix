defmodule AshAuthentication.Phoenix.ComponentsTest do
  @moduledoc false

  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint AshAuthentication.Phoenix.Test.Endpoint

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  test "custom liveview renders the sign in page", %{conn: conn} do
    conn = get(conn, "/custom_lv")
    assert {:ok, view, _html} = live(conn)

    assert element(
             view,
             "div#user-password-sign-in-with-password-wrapper:not(.hidden)",
             "Sign in"
           )
           |> render()
  end
end
