defmodule AshAuthentication.Phoenix.Components.SignIn do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    strategy_class: "CSS class for a `div` surrounding each strategy component.",
    show_banner: "Whether or not to show the banner.",
    authentication_error_container_class:
      "CSS class for the container for the text of the authentication error.",
    authentication_error_text_class: "CSS class for the authentication error text."

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

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}

  ## Props

    * `overrides` - A list of override modules.
    * `otp_app` - The otp app to look for authenticated resources in
    * `live_action` - The live_action being routed to
    * `path` - The path to use as the base for links
    * `reset_path` - The path to use for reset links
    * `register_path` - The path to use for register links
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components, Strategy}
  alias Phoenix.LiveView.{Rendered, Socket}
  import AshAuthentication.Phoenix.Components.Helpers
  import Slug

  @type props :: %{
          optional(:overrides) => [module],
          optional(:path) => String.t(),
          optional(:reset_path) => String.t(),
          optional(:register_path) => String.t(),
          optional(:current_tenant) => String.t()
        }

  @doc false
  @impl true
  @spec update(props, Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    strategies_by_resource =
      socket
      |> otp_app_from_socket()
      |> AshAuthentication.authenticated_resources()
      |> Enum.sort_by(&Info.authentication_subject_name!/1)
      |> Enum.map(fn resource ->
        resource
        |> Info.authentication_strategies()
        |> Enum.group_by(&strategy_style/1)
        |> Map.update(:form, [], &sort_strategies_by_name/1)
        |> Map.update(:link, [], &sort_strategies_by_name/1)
      end)

    socket =
      socket
      |> assign(:strategies_by_resource, strategies_by_resource)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:live_action, fn -> :sign_in end)
      |> assign_new(:path, fn -> "/" end)
      |> assign_new(:reset_path, fn -> nil end)
      |> assign_new(:register_path, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= if override_for(@overrides, :show_banner, true) do %>
        <.live_component module={Components.Banner} id="sign-in-banner" overrides={@overrides} />
      <% end %>

      <%= for {strategies, i} <- Enum.with_index(@strategies_by_resource) do %>
        <%= if Enum.any?(strategies.form) do %>
          <%= for strategy <- strategies.form do %>
            <.strategy
              component={component_for_strategy(strategy)}
              live_action={@live_action}
              strategy={strategy}
              path={@path}
              reset_path={@reset_path}
              register_path={@register_path}
              overrides={@overrides}
              current_tenant={@current_tenant}
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
          <%= for strategy <- strategies.link do %>
            <.strategy
              component={component_for_strategy(strategy)}
              live_action={@live_action}
              strategy={strategy}
              path={@path}
              reset_path={@reset_path}
              register_path={@register_path}
              overrides={@overrides}
              current_tenant={@current_tenant}
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
        path={@path}
        reset_path={@reset_path}
        register_path={@register_path}
        live_action={@live_action}
        overrides={@overrides}
        current_tenant={@current_tenant}
      />
    </div>
    """
  end

  defp sort_strategies_by_name(strategies), do: Enum.sort_by(strategies, & &1.name)

  defp strategy_id(strategy) do
    subject_name =
      strategy.resource
      |> Info.authentication_subject_name!()

    "sign-in-#{subject_name}-with-#{strategy.name}"
    |> slugify()
  end

  defp strategy_style(%AshAuthentication.AddOn.Confirmation{}), do: nil
  defp strategy_style(%Strategy.Password{}), do: :form
  defp strategy_style(%Strategy.MagicLink{}), do: :form
  defp strategy_style(_), do: :link

  defp component_for_strategy(strategy) do
    strategy.__struct__
    |> Module.split()
    |> List.replace_at(1, "Components")
    |> List.insert_at(1, "Phoenix")
    |> Module.concat()
  end
end
