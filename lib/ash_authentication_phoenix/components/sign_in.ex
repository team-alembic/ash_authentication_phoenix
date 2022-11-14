defmodule AshAuthentication.Phoenix.Components.SignIn do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    provider_class: "CSS class for a `div` surrounding each provider component."

  @moduledoc """
  Renders sign in mark-up for an authenticated resource.

  This means that it will render sign-in UI for all of the authentication
  providers for a resource.

  For each provider configured on the resource a component name is inferred
  (e.g. `AshAuthentication.PasswordAuthentication` becomes
  `AshAuthentication.Phoenix.Components.PasswordAuthentication`) and is rendered
  into the output.

  ## Component hierarchy

  This is the top-most authentication component.

  Children:

    * `AshAuthentication.Phoenix.Components.PasswordAuthentication`.

  ## Props

    * `config` - The configuration man as per
    `AshAuthentication.authenticated_resources/1`.  Required.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use Phoenix.LiveComponent
  alias AshAuthentication.Phoenix.Components
  alias Phoenix.LiveView.{Rendered, Socket}
  import AshAuthentication.Phoenix.Components.Helpers

  @doc false
  @impl true
  @spec update(Socket.assigns(), Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    resources =
      socket
      |> otp_app_from_socket()
      |> AshAuthentication.authenticated_resources()
      |> Enum.group_by(& &1.subject_name)
      |> Enum.sort_by(&elem(&1, 0))

    socket =
      socket
      |> assign(assigns)
      |> assign(:resources, resources)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@socket, :root_class)}>
      <.live_component module={Components.Banner} socket={@socket} id="sign-in-banner" />

      <%= for {_subject_name, configs} <- @resources do %>
        <%= for config <- configs do %>
          <%= if has_form?(config) do %>
            <%= for widget <- form_components(config) do %>
              <.widget widget={widget} socket={@socket} />
            <% end %>
          <% end %>
          <%= if has_form?(config) && has_links?(config) do %>
            <.live_component module={Components.HorizontalRule} id="hr" />
          <% end %>
          <%= if has_links?(config) do %>
            <%= for widget <- link_components(config) do %>
              <.widget widget={widget} socket={@socket} />
            <% end %>
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp widget(assigns) do
    ~H"""
    <div class={override_for(@socket, :provider_class)}>
      <.live_component
        module={@widget.component}
        id={provider_id(@widget.provider, @widget.config)}
        provider={@widget.provider}
        config={@widget.config}
      />
    </div>
    """
  end

  defp provider_id(provider, config) do
    "sign-in-#{config.subject_name}-with-#{provider.provides(config.resource)}"
  end

  defp has_form?(config), do: config |> form_components() |> Enum.any?()
  defp has_links?(config), do: config |> link_components() |> Enum.any?()

  defp form_components(config) do
    config
    |> provider_components()
    |> Enum.filter(& &1.component.form?())
  end

  defp link_components(config) do
    config
    |> provider_components()
    |> Enum.filter(& &1.component.link?())
  end

  defp provider_components(%{providers: providers, resource: resource} = config) do
    providers
    |> Enum.sort_by(& &1.provides(resource))
    |> Enum.map(fn provider ->
      component =
        provider
        |> Module.split()
        |> List.last()
        |> then(&Module.concat(Components, &1))

      %{component: component, provider: provider, config: config}
    end)
    |> Enum.filter(&Code.ensure_loaded?(&1.component))
  end
end
