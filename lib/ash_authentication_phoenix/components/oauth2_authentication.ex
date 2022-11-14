defmodule AshAuthentication.Phoenix.Components.OAuth2Authentication do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS classes for the root `div` element.",
    link_class: "CSS classes for the `a` element."

  @moduledoc """
  Generates a sign-in button for OAuth2.

  ## Component heirarchy

  This is the top-most provider specific component, nested below
  `AshAuthentication.Phoenix.Components.SignIn`.

  ## Props

    * `provider` - The provider module.
    * `config` - The configuration as per
      `AshAuthentication.authenticated_resources/1`.  Required.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use Phoenix.LiveComponent
  use AshAuthentication.Phoenix.AuthenticationComponent, style: :link
  alias Phoenix.LiveView.{Rendered, Socket}
  import AshAuthentication.Phoenix.Components.Helpers, only: [route_helpers: 1]
  import Phoenix.HTML.Form

  @doc false
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@socket, :root_class)}>
      <a
        href={
          route_helpers(@socket).auth_request_path(
            @socket.endpoint,
            :request,
            @config.subject_name,
            @provider.provides(@config.resource)
          )
        }
        class={override_for(@socket, :link_class)}
      >
        Sign in with <%= provider_name(@provider, @config) %>
      </a>
    </div>
    """
  end

  defp provider_name(provider, config) do
    config.resource
    |> provider.provides()
    |> case do
      "oauth2" -> "OAuth"
      other -> humanize(other)
    end
  end
end
