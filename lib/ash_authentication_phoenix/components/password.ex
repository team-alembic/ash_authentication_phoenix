defmodule AshAuthentication.Phoenix.Components.Password do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    hide_class: "CSS class to apply to hide an element.",
    show_first:
      "The form to show on first load.  Either `:sign_in` or `:register`. Only relevant if paths aren't set for them in the router.",
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

  ## Slots

    * `sign_in_extra` - rendered inside the sign-in form with the form passed as
      a slot argument.
    * `register_extra` - rendered inside the registration form with the form
      passed as a slot argument.
    * `reset_extra` - rendered inside the reset form with the form passed as a
      slot argument.
    * `path` - used as the base for links to other pages.
    * `reset_path` - the path to use for reset links.
    * `register_path` - the path to use for register links.

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

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components.Password, Strategy}
  alias Phoenix.LiveView.{JS, Rendered, Socket}
  import Slug

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          optional(:overrides) => [module],
          optional(:live_action) => :sign_in | :register,
          optional(:path) => String.t(),
          optional(:current_tenant) => String.t()
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
      |> Info.authentication_subject_name!()
      |> to_string()
      |> slugify()

    strategy_name =
      assigns.strategy
      |> Strategy.name()
      |> to_string()
      |> slugify()

    register_enabled? =
      strategy.registration_enabled? && override_for(assigns.overrides, :register_toggle_text)

    reset_enabled? =
      strategy.resettable && override_for(assigns.overrides, :reset_toggle_text)

    reset_id =
      strategy.resettable &&
        generate_id(
          subject_name,
          strategy_name,
          strategy.resettable.request_password_reset_action_name
        )

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
      |> assign(:hide_class, override_for(assigns.overrides, :hide_class))
      |> assign(:reset_enabled?, reset_enabled?)
      |> assign(:register_enabled?, register_enabled?)
      |> assign(:sign_in_enabled?, !is_nil(override_for(assigns.overrides, :sign_in_toggle_text)))
      |> assign(:reset_id, reset_id)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:live_action, fn -> :sign_in end)
      |> assign_new(:path, fn -> "/" end)
      |> assign_new(:reset_path, fn -> nil end)
      |> assign_new(:register_path, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)

    show =
      if assigns[:live_action] == :sign_in && is_nil(assigns[:reset_path]) &&
           is_nil(assigns[:register_path]) do
        assigns[:show_first] || :sign_in
      else
        assigns[:live_action]
      end

    assigns = assign(assigns, :show, show)

    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <div id={"#{@sign_in_id}-wrapper"} class={if @show == :sign_in, do: nil, else: @hide_class}>
        <.live_component
          :let={form}
          module={Password.SignInForm}
          id={@sign_in_id}
          strategy={@strategy}
          label={false}
          overrides={@overrides}
          current_tenant={@current_tenant}
        >
          <%= if @sign_in_extra do %>
            <div class={override_for(@overrides, :slot_class)}>
              <%= render_slot(@sign_in_extra, form) %>
            </div>
          <% end %>

          <div class={override_for(@overrides, :interstitial_class)}>
            <%= if @reset_enabled? do %>
              <.toggler
                message={override_for(@overrides, :reset_toggle_text)}
                show={@reset_id}
                hide={[@sign_in_id, @register_id]}
                to={@reset_path}
                overrides={@overrides}
              />
            <% end %>

            <%= if @register_enabled? do %>
              <.toggler
                message={override_for(@overrides, :register_toggle_text)}
                show={@register_id}
                hide={[@sign_in_id, @reset_id]}
                to={@register_path}
                overrides={@overrides}
              />
            <% end %>
          </div>
        </.live_component>
      </div>

      <%= if @register_enabled? do %>
        <div
          id={"#{@register_id}-wrapper"}
          class={if @live_action == :register, do: nil, else: @hide_class}
        >
          <.live_component
            :let={form}
            module={Password.RegisterForm}
            id={@register_id}
            strategy={@strategy}
            label={false}
            overrides={@overrides}
            current_tenant={@current_tenant}
          >
            <%= if @register_extra do %>
              <div class={override_for(@overrides, :slot_class)}>
                <%= render_slot(@register_extra, form) %>
              </div>
            <% end %>

            <div class={override_for(@overrides, :interstitial_class)}>
              <%= if @reset_enabled? do %>
                <.toggler
                  message={override_for(@overrides, :reset_toggle_text)}
                  show={[@reset_id]}
                  hide={[@sign_in_id, @register_id]}
                  to={@reset_path}
                  overrides={@overrides}
                />
              <% end %>
              <%= if @sign_in_enabled? do %>
                <.toggler
                  message={override_for(@overrides, :sign_in_toggle_text)}
                  show={@sign_in_id}
                  hide={[@register_id, @reset_id]}
                  to={if @register_path, do: @path}
                  overrides={@overrides}
                />
              <% end %>
            </div>
          </.live_component>
        </div>
      <% end %>

      <%= if @reset_enabled? do %>
        <div id={"#{@reset_id}-wrapper"} class={if @show == :reset, do: nil, else: @hide_class}>
          <.live_component
            :let={form}
            module={Password.ResetForm}
            id={@reset_id}
            strategy={@strategy}
            label={false}
            overrides={@overrides}
            current_tenant={@current_tenant}
          >
            <%= if @reset_extra do %>
              <div class={override_for(@overrides, :slot_class)}>
                <%= render_slot(@reset_extra, form) %>
              </div>
            <% end %>

            <div class={override_for(@overrides, :interstitial_class)}>
              <%= if @register_enabled? do %>
                <.toggler
                  to={@register_path}
                  show={@register_id}
                  hide={[@sign_in_id, @reset_id]}
                  message={override_for(@overrides, :register_toggle_text)}
                  overrides={@overrides}
                />
              <% end %>
              <%= if @sign_in_enabled? do %>
                <.toggler
                  message={override_for(@overrides, :sign_in_toggle_text)}
                  show={@sign_in_id}
                  hide={[@register_id, @reset_id]}
                  to={if @reset_path, do: @path}
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
    if assigns[:to] do
      ~H"""
      <.link patch={@to} class={override_for(@overrides, :toggler_class)}>
        <%= @message %>
      </.link>
      """
    else
      ~H"""
      <a href="#" phx-click={toggle_js(@show, @hide)} class={override_for(@overrides, :toggler_class)}>
        <%= @message %>
      </a>
      """
    end
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
