defmodule AshAuthentication.Phoenix.Components.SignIn do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    strategy_class: "CSS class for a `div` surrounding each strategy component.",
    show_banner: "Whether or not to show the banner."

  @moduledoc """
  Renders sign in mark-up for an authenticated resource.

  This means that it will render sign-in UI for all of the authentication
  strategies for a resource.

  For each strategy configured on the resource a component name is inferred
  (e.g. `AshAuthentication.Strategy.Password` becomes
  `AshAuthentication.Phoenix.Components.Password`) and is rendered into the
  output.

  ## Component hierarchy

  This is the top-most authentication component.

  Children:

  * `AshAuthentication.Phoenix.Components.Password`.
  * `AshAuthentication.Phoenix.Components.OAuth2`.
  * `AshAuthentication.Phoenix.Components.Banner`.
  * `AshAuthentication.Phoenix.Components.HorizontalRule`.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}

  ## Props

    * `overrides` - A list of override modules. Required.
    * `strategy_components` - A list of strategy components that can be used.
      Required.
  """

  use Phoenix.LiveComponent
  alias AshAuthentication.{Info, Phoenix.Components, Strategy}
  alias Phoenix.LiveView.{Rendered, Socket}
  import AshAuthentication.Phoenix.Components.Helpers
  import Slug

  @type props :: %{
          required(:strategy_components) => [module],
          required(:overrides) => [module]
        }

  @doc false
  @impl true
  @spec update(props, Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    strategy_components =
      assigns.strategy_components
      |> Stream.flat_map(fn component ->
        Stream.map(component.__strategies__(), &{&1, component})
      end)
      |> Map.new()

    strategies_by_resource =
      socket
      |> otp_app_from_socket()
      |> AshAuthentication.authenticated_resources()
      |> Enum.sort_by(&Info.authentication_subject_name!/1)
      |> Enum.map(fn resource ->
        resource
        |> Info.authentication_strategies()
        |> Stream.map(&{&1, Map.get(strategy_components, &1.__struct__)})
        |> Stream.reject(&is_nil(elem(&1, 1)))
        |> Enum.group_by(&elem(&1, 1).__visual_style__())
        |> Map.update(:form, [], &sort_strategies_by_name/1)
        |> Map.update(:link, [], &sort_strategies_by_name/1)
      end)

    socket =
      socket
      |> assign(assigns)
      |> assign(:strategies_by_resource, strategies_by_resource)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= if override_for(@overrides, :show_banner, true) do %>
        <.live_component
          module={Components.Banner}
          socket={@socket}
          id="sign-in-banner"
          overrides={@overrides}
        />
      <% end %>

      <%= for {strategies, i} <- Enum.with_index(@strategies_by_resource) do %>
        <%= if Enum.any?(strategies.form) do %>
          <%= for {strategy, component} <- strategies.form do %>
            <.strategy
              component={component}
              strategy={strategy}
              socket={@socket}
              overrides={@overrides}
            />
          <% end %>
        <% end %>

        <%= if Enum.any?(strategies.form) && Enum.any?(strategies.link) do %>
          <.live_component
            module={Components.HorizontalRule}
            id={"sign-in-hr-#{i}"}
            overrides={@overrides}
          />
        <% end %>

        <%= if Enum.any?(strategies.link) do %>
          <%= for {strategy, component} <- strategies.link do %>
            <.strategy
              component={component}
              strategy={strategy}
              socket={@socket}
              overrides={@overrides}
            />
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp strategy(assigns) do
    ~H"""
    <div class={override_for(@overrides, :strategy_class)}>
      <.live_component
        module={@component}
        id={strategy_id(@strategy)}
        strategy={@strategy}
        overrides={@overrides}
      />
    </div>
    """
  end

  defp sort_strategies_by_name(strategies),
    do: Enum.sort_by(strategies, &Strategy.name(elem(&1, 0)))

  defp strategy_id(strategy) do
    subject_name =
      strategy.resource
      |> Info.authentication_subject_name!()

    strategy_name = Strategy.name(strategy)

    "sign-in-#{subject_name}-with-#{strategy_name}"
    |> slugify()
  end
end
