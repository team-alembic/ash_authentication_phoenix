defmodule AshAuthentication.Phoenix.Test.ConnCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint AshAuthentication.Phoenix.Test.Endpoint

      use Phoenix.VerifiedRoutes,
        endpoint: @endpoint,
        router: AshAuthentication.Phoenix.Test.Router

      # statics: ~w(assets fonts images favicon.ico robots.txt)

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import AshAuthentication.Phoenix.Test.ConnCase
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
