# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Confirm do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    strategy_class: "CSS class for a `div` surrounding each strategy component.",
    show_banner: "Whether or not to show the banner."

  @moduledoc """
  Renders a confirmation button.

  ## Component hierarchy

  Children:
    * `AshAuthentication.Phoenix.Components.ConfirmForm`

  ## Props

    * `token` - The confirmation token.
    * `resource` - The resource to confirm.
    * `strategy` - The strategy to confirm.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.
    * `otp_app` - The otp app to look for authenticated resources in

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components}
  alias Phoenix.LiveView.{Rendered, Socket}

  @type props :: %{
          required(:token) => String.t(),
          optional(:overrides) => [module],
          optional(:current_tenant) => term(),
          optional(:gettext_fn) => {module, atom}
        }

  @doc false
  @impl true
  @spec update(props, Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    strategy = Info.strategy!(assigns.resource, assigns.strategy)

    socket =
      socket
      |> assign(:strategy, strategy)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
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
          id="confirm-banner"
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />
      <% end %>
      <div class={override_for(@overrides, :strategy_class)}>
        <.live_component
          module={Components.Confirm.Form}
          auth_routes_prefix={@auth_routes_prefix}
          current_tenant={@current_tenant}
          strategy={@strategy}
          token={@token}
          id={"#{Info.authentication_subject_name!(@strategy.resource)}-#{@strategy.name}-confirm-form"}
          label={false}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />
      </div>
    </div>
    """
  end
end
