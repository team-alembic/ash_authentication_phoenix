defmodule AshAuthentication.Phoenix.Components.OAuth2 do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS classes for the root `div` element.",
    link_class: "CSS classes for the `a` element."

  @moduledoc """
  Generates a sign-in button for OAuth2.

  ## Component heirarchy

  This is the top-most provider specific component, nested below
  `AshAuthentication.Phoenix.Components.SignIn`.

  ## Props

    * `strategy` - The strategy configuration as per
      `AshAuthentication.Info.strategy/2`.  Required.
    * `socket` - Needed to infer the otp-app from the Phoenix endpoint.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use Phoenix.LiveComponent
  alias AshAuthentication.Info
  alias Phoenix.LiveView.{Rendered, Socket}
  import AshAuthentication.Phoenix.Components.Helpers, only: [route_helpers: 1]
  import Phoenix.HTML.Form

  @doc false
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    assigns =
      assigns
      |> assign(:subject_name, Info.authentication_subject_name!(assigns.strategy.resource))

    ~H"""
    <div class={override_for(@socket, :root_class)}>
      <a
        href={
          route_helpers(@socket).auth_path(
            @socket.endpoint,
            {@subject_name, @strategy.name, :request}
          )
        }
        class={override_for(@socket, :link_class)}
      >
        Sign in with <%= strategy_name(@strategy) %>
      </a>
    </div>
    """
  end

  defp strategy_name(strategy) do
    case strategy.name do
      :oauth2 -> "OAuth"
      other -> humanize(other)
    end
  end
end
