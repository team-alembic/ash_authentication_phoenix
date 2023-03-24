defmodule AshAuthentication.Phoenix.Components.Password do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    hide_class: "CSS class to apply to hide an element.",
    show_first: "The form to show on first load.  Either `:sign_in` or `:register`.",
    interstitial_class: "CSS class for the `div` element between the form and the button.",
    sign_in_toggle_text:
      "Toggle text to display when the sign in form is not showing (or `nil` to disable).",
    register_toggle_text:
      "Toggle text to display when the register form is not showing (or `nil` to disable).",
    reset_toggle_text:
      "Toggle text to display when the reset form is not showing (or `nil` to disable).",
    toggler_class: "CSS class for the toggler `a` element.",
    slot_class: "CSS class for the `div` surrounding the slot."

  @moduledoc """
  Generates sign in, registration and reset forms for a resource.

  ## Component hierarchy

  This is the top-most strategy-specific component, nested below
  `AshAuthentication.Phoenix.Components.SignIn`.

  Children:

    * `AshAuthentication.Phoenix.Components.Password.SignInForm`
    * `AshAuthentication.Phoenix.Components.Password.RegisterForm`
    * `AshAuthentication.Phoenix.Components.Password.ResetForm`

  ## Props

    * `strategy` - The strategy configuration as per
      `AshAuthentication.Info.strategy/2`.  Required.
    * `overrides` - A list of override modules.
    * `show_first` - either `:sign_in`, `:register` or `:reset` which controls
      which form is visible on first load.

  ## Slots

    * `sign_in_extra` - rendered inside the sign-in form with the form passed as
      a slot argument.
    * `register_extra` - rendered inside the registration form with the form
      passed as a slot argument.
    * `reset_extra` - rendered inside the reset form with the form passed as a
      slot argument.

  ```heex
  <.live_component
    module={#{inspect(__MODULE__)}}
    strategy={AshAuthentication.Info.strategy!(Example.User, :password)}
    id="user-with-password"
    socket={@socket}
    overrides={[AshAuthentication.Phoenix.Overrides.Default]}>

    <:sign_in_extra :let={form}>
      <.input field={form[:capcha]} />
    </:sign_in_extra>

    <:register_extra :let={form}>
      <.input field={form[:name]} />
    </:register_extra>

    <:reset_extra :let={form}>
      <.input field={form[:capcha]} />
    </:reset_extra>
  </.live_component>
  ```


  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use Phoenix.LiveComponent
  alias AshAuthentication.{Info, Phoenix.Components.Password, Strategy}
  alias Phoenix.LiveView.{JS, Rendered, Socket}
  import Slug

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          optional(:overrides) => [module]
        }

  slot :sign_in_extra
  slot :register_extra
  slot :reset_extra

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
      assigns.strategy
      |> Strategy.name()
      |> to_string()
      |> slugify()

    reset_enabled? =
      Enum.any?(strategy.resettable) && override_for(assigns.overrides, :reset_toggle_text)

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
      |> assign_new(:show_first, fn -> override_for(assigns.overrides, :show_first, :sign_in) end)
      |> assign(:hide_class, override_for(assigns.overrides, :hide_class))
      |> assign(:reset_enabled?, reset_enabled?)
      |> assign(
        :register_enabled?,
        !is_nil(override_for(assigns.overrides, :register_toggle_text))
      )
      |> assign(:sign_in_enabled?, !is_nil(override_for(assigns.overrides, :sign_in_toggle_text)))
      |> assign(:reset_id, reset_id)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)

    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <div id={"#{@sign_in_id}-wrapper"} class={unless @show_first == :sign_in, do: @hide_class}>
        <.live_component
          :let={form}
          module={Password.SignInForm}
          id={@sign_in_id}
          strategy={@strategy}
          label={false}
          overrides={@overrides}
        >
          <%= if @sign_in_extra do %>
            <div class={override_for(@overrides, :slot_class)}>
              <%= render_slot(@sign_in_extra, form) %>
            </div>
          <% end %>

          <div class={override_for(@overrides, :interstitial_class)}>
            <%= if @reset_enabled? do %>
              <.toggler
                show={@reset_id}
                hide={[@sign_in_id, @register_id]}
                message={override_for(@overrides, :reset_toggle_text)}
                overrides={@overrides}
              />
            <% end %>

            <%= if @register_enabled? do %>
              <.toggler
                show={@register_id}
                hide={[@sign_in_id, @reset_id]}
                message={override_for(@overrides, :register_toggle_text)}
                overrides={@overrides}
              />
            <% end %>
          </div>
        </.live_component>
      </div>

      <%= if @register_enabled? do %>
        <div id={"#{@register_id}-wrapper"} class={unless @show_first == :register, do: @hide_class}>
          <.live_component
            :let={form}
            module={Password.RegisterForm}
            id={@register_id}
            strategy={@strategy}
            label={false}
            overrides={@overrides}
          >
            <%= if @register_extra do %>
              <div class={override_for(@overrides, :slot_class)}>
                <%= render_slot(@register_extra, form) %>
              </div>
            <% end %>

            <div class={override_for(@overrides, :interstitial_class)}>
              <%= if @reset_enabled? do %>
                <.toggler
                  show={@reset_id}
                  hide={[@sign_in_id, @register_id]}
                  message={override_for(@overrides, :reset_toggle_text)}
                  overrides={@overrides}
                />
              <% end %>
              <%= if @sign_in_enabled? do %>
                <.toggler
                  show={@sign_in_id}
                  hide={[@register_id, @reset_id]}
                  message={override_for(@overrides, :sign_in_toggle_text)}
                  overrides={@overrides}
                />
              <% end %>
            </div>
          </.live_component>
        </div>
      <% end %>

      <%= if @reset_enabled? do %>
        <div id={"#{@reset_id}-wrapper"} class={unless @show_first == :reset, do: @hide_class}>
          <.live_component
            :let={form}
            module={Password.ResetForm}
            id={@reset_id}
            strategy={@strategy}
            label={false}
            overrides={@overrides}
          >
            <%= if @reset_extra do %>
              <div class={override_for(@overrides, :slot_class)}>
                <%= render_slot(@reset_extra, form) %>
              </div>
            <% end %>

            <div class={override_for(@overrides, :interstitial_class)}>
              <%= if @register_enabled? do %>
                <.toggler
                  show={@register_id}
                  hide={[@sign_in_id, @reset_id]}
                  message={override_for(@overrides, :register_toggle_text)}
                  overrides={@overrides}
                />
              <% end %>
              <%= if @sign_in_enabled? do %>
                <.toggler
                  show={@sign_in_id}
                  hide={[@register_id, @reset_id]}
                  message={override_for(@overrides, :sign_in_toggle_text)}
                  overrides={@overrides}
                />
              <% end %>
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
    show_wrapper = "##{show}-wrapper"

    js =
      js
      |> JS.show(to: show_wrapper)
      |> JS.focus_first(to: show_wrapper)

    hides
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(js, fn hide, js ->
      JS.hide(js, to: "##{hide}-wrapper")
    end)
  end
end
