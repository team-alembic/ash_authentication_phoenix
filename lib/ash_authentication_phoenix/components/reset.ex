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

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use Phoenix.LiveComponent
  alias AshAuthentication.{Info, Phoenix.Components, Strategy.Password}
  alias Phoenix.LiveView.{Rendered, Socket}
  import AshAuthentication.Phoenix.Components.Helpers

  @type props :: %{
          required(:token) => String.t(),
          optional(:overrides) => [module]
        }

  @doc false
  @impl true
  @spec update(props, Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    strategies =
      socket
      |> otp_app_from_socket()
      |> AshAuthentication.authenticated_resources()
      |> Enum.sort_by(&Info.authentication_subject_name!/1)
      |> Stream.flat_map(&Info.authentication_strategies/1)
      |> Stream.filter(&is_struct(&1, Password))
      |> Enum.filter(&Enum.any?(&1.resettable))

    socket =
      socket
      |> assign(assigns)
      |> assign(strategies: strategies)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= if override_for(@overrides, :show_banner, true) do %>
        <.live_component module={Components.Banner} socket={@socket} id="sign-in-banner" />
      <% end %>

      <%= for strategy <- @strategies do %>
        <div class={override_for(@overrides, :strategy_class)}>
          <.live_component
            module={Components.Reset.Form}
            strategy={strategy}
            token={@token}
            socket={@socket}
            id="reset-form"
            label={false}
            overrides={@overrides}
          />
        </div>
      <% end %>
    </div>
    """
  end
end
