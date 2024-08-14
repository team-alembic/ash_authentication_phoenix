defmodule AshAuthentication.Phoenix.Test.AuthView do
  @moduledoc false
  use Phoenix.Component

  @doc false
  def success(assigns), do: ~H"<p>Success</p>"
  @doc false
  def signed_out(assigns), do: ~H"<p>Signed out</p>"
end
