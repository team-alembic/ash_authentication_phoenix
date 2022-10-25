defmodule AshAuthentication.Phoenix.Components.SignIn do
  @moduledoc """
  Renders sign in mark-up for an authenticated resource.

  This means that it will render sign-in UI for all of the authentication
  providers for a resource.

  For each provider configured on the resource a component name is inferred
  (e.g. `AshAuthentication.PasswordAuthentication` becomes
  `AshAuthentication.Phoenix.Components.PasswordAuthentication`) and is rendered
  into the output.

  ## Component heirarchy

  This is the top-most authentication component.

  Children:

    * `AshAuthentication.Phoenix.Components.PasswordAuthentication`.

  ## Props

    * `config` - The configuration man as per
    `AshAuthentication.authenticated_resources/1`.  Required.

  ## Overrides

  See `AshAuthentication.Phoenix.Overrides` for more information.

    * `sign_in_box_css_class` - applied to the root `div` element of this component.
    * `sign_in_row_css_class` - applied to the spacer element, if enabled.
  """

  use Phoenix.LiveComponent
  alias AshAuthentication.Phoenix.Components
  alias Phoenix.LiveView.Rendered
  import AshAuthentication.Phoenix.Components.Helpers

  @type props :: %{required(:config) => AshAuthentication.resource_config()}

  @doc false
  @spec render(props) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@socket, :sign_in_box_css_class)}>
      <%= for provider <- @config.providers do %>
        <div class={override_for(@socket, :sign_in_row_css_class)}>
          <.live_component module={component_for_provider(provider)} id={provider_id(provider, @config)} provider={provider} config={@config} />
        </div>
      <% end %>
    </div>
    """
  end

  defp component_for_provider(provider),
    do:
      provider
      |> Module.split()
      |> List.last()
      |> then(&Module.concat(Components, &1))

  defp provider_id(provider, config) do
    "sign-in-#{config.subject_name}-#{provider.provides()}"
  end
end
