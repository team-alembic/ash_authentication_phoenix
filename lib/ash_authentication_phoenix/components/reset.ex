# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Reset do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    strategy_class: "CSS class for a `div` surrounding each strategy component.",
    show_banner: "Whether or not to show the banner."

  @moduledoc """
  Renders a password-reset form.

  ## Component hierarchy

  Children:

    * `AshAuthentication.Phoenix.Components.Password.Input.password_field/1`
    * `AshAuthentication.Phoenix.Components.Password.Input.password_confirmation_field/1`
    * `AshAuthentication.Phoenix.Components.Password.Input.submit/1`

  ## Props

    * `token` - The reset token.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.
    * `otp_app` - The otp app to look for authenticated resources in

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components, Strategy.Password}
  alias Phoenix.LiveView.{Rendered, Socket}
  import AshAuthentication.Phoenix.Components.Helpers

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

    strategies =
      socket
      |> otp_app_from_socket()
      |> AshAuthentication.authenticated_resources()
      |> Enum.sort_by(&Info.authentication_subject_name!/1)
      |> Stream.flat_map(&Info.authentication_strategies/1)
      |> Stream.filter(&is_struct(&1, Password))
      |> Enum.filter(& &1.resettable)

    socket =
      socket
      |> assign(strategies: strategies)
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
          id="sign-in-banner"
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />
      <% end %>

      <%= for strategy <- @strategies do %>
        <div class={override_for(@overrides, :strategy_class)}>
          <.live_component
            module={Components.Reset.Form}
            auth_routes_prefix={@auth_routes_prefix}
            current_tenant={@current_tenant}
            strategy={strategy}
            token={@token}
            id={"#{Info.authentication_subject_name!(strategy.resource)}-#{strategy.name}-reset-form"}
            label={false}
            overrides={@overrides}
            gettext_fn={@gettext_fn}
          />
        </div>
      <% end %>
    </div>
    """
  end
end
