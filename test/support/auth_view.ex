defmodule AshAuthentication.Phoenix.Test.AuthView do
  use Phoenix.Component

  def success(assigns), do:  ~H"<p>Success</p>"
  def signed_out(assigns), do:  ~H"<p>Signed out</p>"
end
