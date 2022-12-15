defmodule DevWeb.AuthOverrides do
  @moduledoc false
  use AshAuthentication.Phoenix.Overrides
  alias AshAuthentication.Phoenix.Components

  override Components.Banner do
    set :image_url, "https://media.giphy.com/media/g7GKcSzwQfugw/giphy.gif"
  end
end
