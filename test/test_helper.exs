ExUnit.start()

AshAuthentication.Phoenix.Test.Endpoint.start_link()

defmodule AshAuthentication.Phoenix.Test.Helper do
  def gettext(_msgid, _bindings) do
    "Never gonna give you up!"
  end
end
