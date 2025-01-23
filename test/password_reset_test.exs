defmodule AshAuthentication.Phoenix.PasswordResetTest do
  @moduledoc false

  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  require Ash.Query

  @endpoint AshAuthentication.Phoenix.Test.Endpoint

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  test "reset_route routes liveview renders the password reset page", %{conn: conn} do
    conn = get(conn, "/password-reset/my_token_213")
    assert {:ok, _view, html} = live(conn)
    assert html =~ "Password reset"
  end

  test "reset_route routes liveview honours external gettext_fn", %{conn: conn} do
    # Translator stub at AshAuthentication.Phoenix.Test.Gettext.translate_auth
    conn = get(conn, "/vergessen/meine_wertmarke_213")
    assert {:ok, _view, html} = live(conn)
    refute html =~ "Password reset"
    assert html =~ "ever gonna"
  end

  test "reset_route routes liveview honours external gettext_backend", %{conn: conn} do
    # Translator stub at AshAuthentication.Phoenix.Test.Gettext
    conn = get(conn, "/vergessen_backend/meine_wertmarke_213")
    assert {:ok, _view, html} = live(conn)
    refute html =~ "Password reset"
    assert html =~ "ever gonna"
  end
end
