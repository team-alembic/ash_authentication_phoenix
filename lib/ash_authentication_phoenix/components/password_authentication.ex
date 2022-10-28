defmodule AshAuthentication.Phoenix.Components.PasswordAuthentication do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    hide_class: "CSS class to apply to hide an element.",
    show_first: "The form to show on first load.  Either `:sign_in` or `:register`.",
    interstitial_class: "CSS class for the `div` element between the form and the button.",
    sign_in_toggle_text: "Toggle text to display when the sign in form is showing.",
    register_toggle_text: "Toggle text to display when the register form is showing.",
    toggler_class: "CSS class for the toggler `a` element."

  @moduledoc """
  Generates sign in and registration forms for a resource.

  ## Component heirarchy

  This is the top-most provider-specific component, nested below `AshAuthentication.Phoenix.Components.SignIn`.

  Children:

    * `AshAuthentication.Phoenix.Components.PasswordAuthentication.SignInForm`
    * `AshAuthentication.Phoenix.Components.PasswordAuthentication.RegisterForm`

  ## Props

    * `config` - The configuration man as per
      `AshAuthentication.authenticated_resources/1`.
      Required.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use Phoenix.LiveComponent
  alias __MODULE__
  alias AshAuthentication.PasswordAuthentication.Info
  alias Phoenix.LiveView.{JS, Rendered, Socket}

  @doc false
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    config = assigns.config
    provider = assigns.provider
    sign_in_action = Info.sign_in_action_name!(assigns.config.resource)
    register_action = Info.register_action_name!(assigns.config.resource)

    assigns =
      assigns
      |> assign(:sign_in_action, sign_in_action)
      |> assign_new(:sign_in_id, fn ->
        "#{config.subject_name}_#{provider.provides}_#{sign_in_action}"
      end)
      |> assign(:register_action, register_action)
      |> assign_new(:register_id, fn ->
        "#{config.subject_name}_#{provider.provides}_#{register_action}"
      end)
      |> assign_new(:show_first, fn ->
        override_for(assigns.socket, :show_first, :sign_in)
      end)
      |> assign_new(:hide_class, fn ->
        override_for(assigns.socket, :hide_class)
      end)

    ~H"""
    <div class={override_for(@socket, :root_class)}>
      <div id={"#{@sign_in_id}-wrapper"} class={unless @show_first == :sign_in, do: @hide_class}>
        <.live_component
          module={PasswordAuthentication.SignInForm}
          id={@sign_in_id}
          provider={@provider}
          config={@config}
          label={false}
        >
          <div class={override_for(@socket, :interstitial_class)}>
            <.toggler
              socket={@socket}
              register_id={@register_id}
              sign_in_id={@sign_in_id}
              message={override_for(@socket, :sign_in_toggle_text)}
            />
          </div>
        </.live_component>
      </div>
      <div id={"#{@register_id}-wrapper"} class={unless @show_first == :register, do: @hide_class}>
        <.live_component
          module={PasswordAuthentication.RegisterForm}
          id={@register_id}
          provider={@provider}
          config={@config}
          label={false}
        >
          <div class={override_for(@socket, :interstitial_class)}>
            <.toggler
              socket={@socket}
              register_id={@register_id}
              sign_in_id={@sign_in_id}
              message={override_for(@socket, :register_toggle_text)}
            />
          </div>
        </.live_component>
      </div>
    </div>
    """
  end

  def toggler(assigns) do
    ~H"""
    <a
      href="#"
      phx-click={
        JS.toggle(to: "##{@register_id}-wrapper")
        |> JS.toggle(to: "##{@sign_in_id}-wrapper")
      }
      class={override_for(@socket, :toggler_class)}
    >
      <%= @message %>
    </a>
    """
  end
end
