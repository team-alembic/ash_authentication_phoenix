# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.DynamicOidc do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS classes for the root `div` element.",
    link_class: "CSS classes for each connection's `a` element.",
    icon_class: "CSS classes for the icon SVG / `img`."

  @moduledoc """
  Renders a sign-in button per database-stored OIDC connection.

  Unlike the static OAuth2 components, this one queries the strategy's
  `connection_resource` at render time (scoped by the current Ash tenant
  forwarded from the parent `SignIn` component) and renders one button per
  matched row. Connections without rows for the current tenant produce no
  buttons.

  Each connection's `display_name` and `icon_url` (configurable via the
  `oidc_connection do ... end` DSL on the resource) drive the button label
  and icon. If `display_name` isn't set, the button falls back to the host
  portion of `base_url`. If `icon_url` isn't set, a generic OIDC icon is
  rendered.

  ## Component hierarchy

  This is the top-most strategy-specific component, nested below
  `AshAuthentication.Phoenix.Components.SignIn`.

  ## Props

    * `strategy` — the dynamic_oidc strategy struct.
    * `current_tenant` — the Ash tenant to scope connection lookup by.
      Forwarded from `SignIn`. May be `nil` when not multitenant.
    * `context` — opaque action context forwarded from `SignIn`.
    * `overrides` — list of override modules.
    * `gettext_fn` — optional translation function.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.Info
  alias Phoenix.LiveView.Rendered
  import AshAuthentication.Phoenix.Components.Helpers, only: [auth_path: 5]
  import Phoenix.HTML, only: [raw: 1]

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          optional(:current_tenant) => any(),
          optional(:context) => map(),
          optional(:auth_routes_prefix) => String.t(),
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }

  @doc false
  @impl true
  @spec render(props) :: Rendered.t() | no_return
  def render(assigns) do
    assigns =
      assigns
      |> assign(:subject_name, Info.authentication_subject_name!(assigns.strategy.resource))
      |> assign(:connections, list_connections(assigns))
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)

    ~H"""
    <div class={if @connections != [], do: override_for(@overrides, :root_class)}>
      <a
        :for={connection <- @connections}
        href={request_url_for(@socket, @subject_name, @auth_routes_prefix, @strategy, connection)}
        class={override_for(@overrides, :link_class)}
      >
        <.icon icon_url={connection.icon_url} overrides={@overrides} />
        {_gettext("Sign in with #{display_name(connection)}")}
      </a>
    </div>
    """
  end

  @doc false
  def icon(assigns) do
    ~H"""
    <%= if @icon_url do %>
      <img src={@icon_url} class={override_for(@overrides, :icon_class)} alt="" />
    <% else %>
      {raw(default_icon_svg(override_for(@overrides, :icon_class)))}
    <% end %>
    """
  end

  defp list_connections(assigns) do
    strategy = assigns.strategy
    resource = strategy.connection_resource

    fields_to_load =
      [:id, :base_url, :display_name, :icon_url]
      |> Enum.filter(&Ash.Resource.Info.field(resource, &1))

    opts =
      [tenant: assigns[:current_tenant], context: assigns[:context] || %{}]
      |> Enum.reject(&is_nil(elem(&1, 1)))

    case Ash.read(resource, opts) do
      {:ok, rows} ->
        Ash.load!(rows, fields_to_load, opts)

      {:error, _} ->
        []
    end
  rescue
    # Don't crash the entire sign-in page if the connection resource is
    # misconfigured or the database is unreachable; just render nothing for
    # this strategy.
    _ -> []
  end

  defp display_name(connection) do
    connection.display_name ||
      case connection.base_url && URI.parse(connection.base_url) do
        %URI{host: host} when is_binary(host) -> host
        _ -> "SSO"
      end
  end

  defp request_url_for(socket, subject_name, auth_routes_prefix, strategy, connection) do
    socket
    |> auth_path(subject_name, auth_routes_prefix, strategy, :request)
    |> String.replace(":connection_id", to_string(connection.id))
  end

  defp default_icon_svg(class),
    do: ~s"""
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="#{class}">
      <rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect>
      <path d="M7 11V7a5 5 0 0 1 10 0v4"></path>
    </svg>
    """
end
