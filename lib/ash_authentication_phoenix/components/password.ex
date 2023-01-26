defmodule AshAuthentication.Phoenix.Components.Password do
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
  Generates sign in, registration and reset forms for a resource.

  ## Component hierarchy

  This is the top-most provider-specific component, nested below
  `AshAuthentication.Phoenix.Components.SignIn`.

  Children:

    * `AshAuthentication.Phoenix.Components.Password.SignInForm`
    * `AshAuthentication.Phoenix.Components.Password.RegisterForm`
    * `AshAuthentication.Phoenix.Components.Password.ResetForm`

  ## Props

    * `strategy` - The strategy configuration as per
      `AshAuthentication.Info.strategy/2`.  Required.
    * `overrides` - A list of override modules.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use Phoenix.LiveComponent
  alias AshAuthentication.{Info, Phoenix.Components.Password}
  alias Phoenix.LiveView.{JS, Rendered, Socket}
  import Slug

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          optional(:overrides) => [module]
        }

  @doc false
  @impl true
  @spec render(props) :: Rendered.t() | no_return
  def render(assigns) do
    strategy = assigns.strategy

    subject_name =
      assigns.strategy.resource
      |> Info.authentication_get_by_subject_action_name!()
      |> to_string()
      |> slugify()

    strategy_name =
      assigns.strategy.name
      |> to_string()
      |> slugify()

    reset_enabled? = Enum.any?(strategy.resettable)

    reset_id =
      strategy.resettable
      |> Enum.map(
        &generate_id(subject_name, strategy_name, &1.request_password_reset_action_name)
      )
      |> List.first()

    assigns =
      assigns
      |> assign(
        :sign_in_id,
        generate_id(subject_name, strategy_name, strategy.sign_in_action_name)
      )
      |> assign(
        :register_id,
        generate_id(subject_name, strategy_name, strategy.register_action_name)
      )
      |> assign(:show_first, override_for(assigns.overrides, :show_first, :sign_in))
      |> assign(:hide_class, override_for(assigns.overrides, :hide_class))
      |> assign(:reset_enabled?, reset_enabled?)
      |> assign(:reset_id, reset_id)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)

    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <div id={"#{@sign_in_id}-wrapper"} class={unless @show_first == :sign_in, do: @hide_class}>
        <.live_component
          module={Password.SignInForm}
          id={@sign_in_id}
          strategy={@strategy}
          label={false}
          overrides={@overrides}
        >
          <div class={override_for(@overrides, :interstitial_class)}>
            <%= if @reset_enabled? do %>
              <.toggler
                socket={@socket}
                show={@reset_id}
                hide={[@sign_in_id, @register_id]}
                message={override_for(@overrides, :reset_toggle_text)}
                overrides={@overrides}
              />
            <% end %>

            <.toggler
              socket={@socket}
              show={@register_id}
              hide={[@sign_in_id, @reset_id]}
              message={override_for(@overrides, :register_toggle_text)}
              overrides={@overrides}
            />
          </div>
        </.live_component>
      </div>

      <div id={"#{@register_id}-wrapper"} class={unless @show_first == :register, do: @hide_class}>
        <.live_component
          module={Password.RegisterForm}
          id={@register_id}
          strategy={@strategy}
          label={false}
          overrides={@overrides}
        >
          <div class={override_for(@overrides, :interstitial_class)}>
            <%= if @reset_enabled? do %>
              <.toggler
                socket={@socket}
                show={@reset_id}
                hide={[@sign_in_id, @register_id]}
                message={override_for(@overrides, :reset_toggle_text)}
                overrides={@overrides}
              />
            <% end %>
            <.toggler
              socket={@socket}
              show={@sign_in_id}
              hide={[@register_id, @reset_id]}
              message={override_for(@overrides, :sign_in_toggle_text)}
              overrides={@overrides}
            />
          </div>
        </.live_component>
      </div>

      <%= if @reset_enabled? do %>
        <div id={"#{@reset_id}-wrapper"} class={unless @show_first == :reset, do: @hide_class}>
          <.live_component
            module={Password.ResetForm}
            id={@reset_id}
            strategy={@strategy}
            label={false}
            overrides={@overrides}
          >
            <div class={override_for(@overrides, :interstitial_class)}>
              <.toggler
                socket={@socket}
                show={@register_id}
                hide={[@sign_in_id, @reset_id]}
                message={override_for(@overrides, :register_toggle_text)}
                overrides={@overrides}
              />
              <.toggler
                socket={@socket}
                show={@sign_in_id}
                hide={[@register_id, @reset_id]}
                message={override_for(@overrides, :sign_in_toggle_text)}
                overrides={@overrides}
              />
            </div>
          </.live_component>
        </div>
      <% end %>
    </div>
    """
  end

  defp generate_id(subject_name, strategy_name, action) do
    action =
      action
      |> to_string()
      |> slugify()

    "#{subject_name}-#{strategy_name}-#{action}"
  end

  @doc false
  @spec toggler(Socket.assigns()) :: Rendered.t() | no_return
  def toggler(assigns) do
    ~H"""
    <a href="#" phx-click={toggle_js(@show, @hide)} class={override_for(@overrides, :toggler_class)}>
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
