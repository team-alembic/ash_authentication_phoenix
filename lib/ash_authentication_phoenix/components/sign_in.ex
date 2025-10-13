# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.SignIn do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    strategy_class: "CSS class for a `div` surrounding each strategy component.",
    show_banner: "Whether or not to show the banner.",
    authentication_error_container_class:
      "CSS class for the container for the text of the authentication error.",
    authentication_error_text_class: "CSS class for the authentication error text.",
    strategy_display_order:
      "Whether to display the form or link strategies first. Accepted values are `:forms_first` or `:links_first`."

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

    * `otp_app` - The otp app to look for authenticated resources in
    * `live_action` - The live_action being routed to
    * `path` - The path to use as the base for links
    * `reset_path` - The path to use for reset links
    * `register_path` - The path to use for register links
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components, Strategy}
  alias Phoenix.LiveView.{Rendered, Socket}
  import AshAuthentication.Phoenix.Components.Helpers
  import Slug

  @type props :: %{
          optional(:path) => String.t(),
          optional(:reset_path) => String.t(),
          optional(:register_path) => String.t(),
          optional(:current_tenant) => String.t(),
          optional(:context) => map(),
          optional(:overrides) => [module],
          optional(:resources) => [module],
          optional(:gettext_fn) => {module, atom}
        }

  @doc false
  @impl true
  @spec update(props, Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    strategies_by_resource =
      socket.assigns[:resources]
      |> Kernel.||(
        socket
        |> otp_app_from_socket()
        |> AshAuthentication.authenticated_resources()
      )
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
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:live_action, fn -> :sign_in end)
      |> assign_new(:path, fn -> "/" end)
      |> assign_new(:reset_path, fn -> nil end)
      |> assign_new(:register_path, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:context, fn -> %{} end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)

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
          id="sign-in-banner"
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />
      <% end %>

      <%= for {strategies, i} <- Enum.with_index(@strategies_by_resource) do %>
        <% [top_strategies, bottom_strategies] = ordered_strategies(@overrides, strategies) %>

        <.strategies
          live_action={@live_action}
          strategies={top_strategies}
          path={@path}
          auth_routes_prefix={@auth_routes_prefix}
          reset_path={@reset_path}
          register_path={@register_path}
          overrides={@overrides}
          current_tenant={@current_tenant}
          context={@context}
          gettext_fn={@gettext_fn}
        />

        <%= if Enum.any?(strategies.form) && Enum.any?(strategies.link) do %>
          <.live_component
            module={Components.HorizontalRule}
            id={"sign-in-hr-#{i}"}
            overrides={@overrides}
          />
        <% end %>

        <.strategies
          live_action={@live_action}
          strategies={bottom_strategies}
          auth_routes_prefix={@auth_routes_prefix}
          path={@path}
          reset_path={@reset_path}
          register_path={@register_path}
          overrides={@overrides}
          current_tenant={@current_tenant}
          context={@context}
          gettext_fn={@gettext_fn}
        />
      <% end %>
    </div>
    """
  end

  defp strategies(assigns) do
    ~H"""
    <%= if Enum.any?(@strategies) do %>
      <div
        :for={{strategy, module} <- components(@strategies)}
        class={override_for(@overrides, :strategy_class)}
      >
        <.live_component
          module={module}
          id={strategy_id(strategy)}
          strategy={strategy}
          auth_routes_prefix={@auth_routes_prefix}
          path={@path}
          reset_path={@reset_path}
          register_path={@register_path}
          live_action={@live_action}
          overrides={@overrides}
          current_tenant={@current_tenant}
          context={@context}
          gettext_fn={@gettext_fn}
        />
      </div>
    <% end %>
    """
  end

  defp components(strategies) do
    Enum.flat_map(strategies, fn strategy ->
      component = component_for_strategy(strategy)

      if Code.ensure_loaded?(component) do
        [{strategy, component}]
      else
        []
      end
    end)
  end

  defp sort_strategies_by_name(strategies), do: Enum.sort_by(strategies, & &1.name)

  defp ordered_strategies(overrides, strategy_group) do
    case override_for(overrides, :strategy_display_order, :forms_first) do
      :links_first ->
        [strategy_group.link, strategy_group.form]

      _ ->
        [strategy_group.form, strategy_group.link]
    end
  end

  defp strategy_id(strategy) do
    subject_name =
      strategy.resource
      |> Info.authentication_subject_name!()

    "sign-in-#{subject_name}-with-#{strategy.name}"
    |> slugify()
  end

  defp strategy_style(%AshAuthentication.AddOn.Confirmation{}), do: nil
  defp strategy_style(%Strategy.Password{}), do: :form
  defp strategy_style(%Strategy.MagicLink{}), do: :link
  defp strategy_style(%Strategy.RememberMe{}), do: nil
  defp strategy_style(_), do: :link

  defp component_for_strategy(%{strategy_module: Strategy.Apple}), do: Components.Apple

  defp component_for_strategy(strategy) do
    strategy.__struct__
    |> Module.split()
    |> List.replace_at(1, "Components")
    |> List.insert_at(1, "Phoenix")
    |> Module.concat()
  end
end
