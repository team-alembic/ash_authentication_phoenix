defmodule AshAuthentication.Phoenix.Components.PasswordAuthentication do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    hide_class: "CSS class to apply to hide an element.",
    show_first: "The form to show on first load.  Either `:sign_in` or `:register`.",
    interstitial_class: "CSS class for the `div` element between the form and the button.",
    sign_in_toggle_text: "Toggle text to display when the sign in form is not showing.",
    register_toggle_text: "Toggle text to display when the register form is not showing.",
    reset_toggle_text: "Toggle text to display when the reset form is not showing.",
    toggler_class: "CSS class for the toggler `a` element."

  @moduledoc """
  Generates sign in and registration forms for a resource.

  ## Component hierarchy

  This is the top-most provider-specific component, nested below
  `AshAuthentication.Phoenix.Components.SignIn`.

  Children:

    * `AshAuthentication.Phoenix.Components.PasswordAuthentication.SignInForm`
    * `AshAuthentication.Phoenix.Components.PasswordAuthentication.RegisterForm`
    * `AshAuthentication.Phoenix.Components.PasswordAuthentication.ResetForm`

  ## Props

    * `config` - The configuration as per
      `AshAuthentication.authenticated_resources/1`.  Required.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use Phoenix.LiveComponent
  use AshAuthentication.Phoenix.AuthenticationComponent, style: :form
  alias __MODULE__
  alias AshAuthentication.{PasswordAuthentication.Info, PasswordReset}
  alias Phoenix.LiveView.{JS, Rendered, Socket}

  @doc false
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    config = assigns.config
    provider = assigns.provider
    sign_in_action = Info.password_authentication_sign_in_action_name!(assigns.config.resource)
    register_action = Info.password_authentication_register_action_name!(assigns.config.resource)
    reset_enabled? = PasswordReset.enabled?(assigns.config.resource)

    reset_action =
      if reset_enabled?,
        do: PasswordReset.Info.request_password_reset_action_name!(assigns.config.resource)

    assigns =
      assigns
      |> assign(:sign_in_action, sign_in_action)
      |> assign_new(:sign_in_id, fn ->
        "#{config.subject_name}_#{provider.provides(config.resource)}_#{sign_in_action}"
      end)
      |> assign(:register_action, register_action)
      |> assign_new(:register_id, fn ->
        "#{config.subject_name}_#{provider.provides(config.resource)}_#{register_action}"
      end)
      |> assign_new(:show_first, fn ->
        override_for(assigns.socket, :show_first, :sign_in)
      end)
      |> assign_new(:hide_class, fn ->
        override_for(assigns.socket, :hide_class)
      end)
      |> assign(:reset_enabled?, reset_enabled?)
      |> assign_new(:reset_id, fn ->
        if reset_enabled?,
          do: "#{config.subject_name}_#{provider.provides(config.resource)}_#{reset_action}"
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
            <%= if @reset_enabled? do %>
              <.toggler
                socket={@socket}
                show={@reset_id}
                hide={[@sign_in_id, @register_id]}
                message={override_for(@socket, :reset_toggle_text)}
              />
            <% end %>

            <.toggler
              socket={@socket}
              show={@register_id}
              hide={[@sign_in_id, @reset_id]}
              message={override_for(@socket, :register_toggle_text)}
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
            <%= if @reset_enabled? do %>
              <.toggler
                socket={@socket}
                show={@reset_id}
                hide={[@sign_in_id, @register_id]}
                message={override_for(@socket, :reset_toggle_text)}
              />
            <% end %>

            <.toggler
              socket={@socket}
              show={@sign_in_id}
              hide={[@register_id, @reset_id]}
              message={override_for(@socket, :sign_in_toggle_text)}
            />
          </div>
        </.live_component>
      </div>
      <%= if @reset_enabled? do %>
        <div id={"#{@reset_id}-wrapper"} class={unless @show_first == :reset, do: @hide_class}>
          <.live_component
            module={PasswordAuthentication.ResetForm}
            id={@reset_id}
            provider={@provider}
            config={@config}
            label={false}
          >
            <div class={override_for(@socket, :interstitial_class)}>
              <.toggler
                socket={@socket}
                show={@register_id}
                hide={[@sign_in_id, @reset_id]}
                message={override_for(@socket, :register_toggle_text)}
              />

              <.toggler
                socket={@socket}
                show={@sign_in_id}
                hide={[@register_id, @reset_id]}
                message={override_for(@socket, :sign_in_toggle_text)}
              />
            </div>
          </.live_component>
        </div>
      <% end %>
    </div>
    """
  end

  @doc false
  @spec toggler(Socket.assigns()) :: Rendered.t() | no_return
  def toggler(assigns) do
    ~H"""
    <a href="#" phx-click={toggle_js(@show, @hide)} class={override_for(@socket, :toggler_class)}>
      <%= @message %>
    </a>
    """
  end

  defp toggle_js(show, hides, %JS{} = js \\ %JS{}) do
    js =
      js
      |> JS.show(to: "##{show}-wrapper")

    hides
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(js, fn hide, js ->
      JS.hide(js, to: "##{hide}-wrapper")
    end)
  end
end
