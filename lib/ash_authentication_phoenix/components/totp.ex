# SPDX-FileCopyrightText: 2024 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Totp do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    hide_class: "CSS class to apply to hide an element.",
    show_first:
      "The form to show on first load. Either `:sign_in` or `:setup`. Defaults to `:sign_in`.",
    interstitial_class: "CSS class for the `div` element between the form and the toggle.",
    sign_in_toggle_text:
      "Toggle text to display when the sign in form is not showing (or `nil` to disable).",
    setup_toggle_text:
      "Toggle text to display when the setup form is not showing (or `nil` to disable).",
    toggler_class: "CSS class for the toggler `a` element.",
    sign_in_form_module:
      "The Phoenix component to be used for the sign in form. Defaults to `AshAuthentication.Phoenix.Components.Totp.SignInForm`.",
    setup_form_module:
      "The Phoenix component to be used for the setup form. Defaults to `AshAuthentication.Phoenix.Components.Totp.SetupForm`.",
    slot_class: "CSS class for the `div` surrounding the slot."

  @moduledoc """
  Generates sign in and setup forms for TOTP authentication.

  ## Component hierarchy

  This is the top-most strategy-specific component for TOTP, nested below
  `AshAuthentication.Phoenix.Components.SignIn`.

  Children:

    * `AshAuthentication.Phoenix.Components.Totp.SignInForm`
    * `AshAuthentication.Phoenix.Components.Totp.SetupForm`

  ## Props

    * `strategy` - The strategy configuration as per
      `AshAuthentication.Info.strategy/2`.  Required.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.

  ## Slots

    * `sign_in_extra` - rendered inside the sign-in form with the form passed as
      a slot argument.
    * `setup_extra` - rendered inside the setup form with the form passed as a
      slot argument.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components.Totp, Strategy}
  alias Phoenix.LiveView.{JS, Rendered, Socket}
  import Slug

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          optional(:live_action) => :sign_in | :setup,
          optional(:path) => String.t(),
          optional(:current_tenant) => String.t(),
          optional(:context) => map(),
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }

  slot :sign_in_extra
  slot :setup_extra

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

    # Form visibility is controlled by strategy config
    sign_in_enabled? = strategy.sign_in_enabled?
    setup_enabled? = strategy.setup_enabled?

    # Toggle visibility is controlled by override config (nil = no toggle)
    sign_in_toggle_enabled? = override_for(assigns.overrides, :sign_in_toggle_text) != nil
    setup_toggle_enabled? = override_for(assigns.overrides, :setup_toggle_text) != nil

    assigns =
      assigns
      |> assign(
        :sign_in_id,
        generate_id(subject_name, strategy_name, strategy.sign_in_action_name)
      )
      |> assign(
        :setup_id,
        generate_id(subject_name, strategy_name, strategy.setup_action_name)
      )
      |> assign(:hide_class, override_for(assigns.overrides, :hide_class))
      |> assign(:sign_in_enabled?, sign_in_enabled?)
      |> assign(:setup_enabled?, setup_enabled?)
      |> assign(:sign_in_toggle_enabled?, sign_in_toggle_enabled?)
      |> assign(:setup_toggle_enabled?, setup_toggle_enabled?)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:live_action, fn -> :sign_in end)
      |> assign_new(:path, fn -> "/" end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:context, fn -> %{} end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)

    show =
      if assigns[:live_action] == :sign_in do
        override_for(assigns.overrides, :show_first) || :sign_in
      else
        assigns[:live_action]
      end

    assigns = assign(assigns, :show, show)

    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= if @sign_in_enabled? do %>
        <div id={"#{@sign_in_id}-wrapper"} class={if @show == :sign_in, do: nil, else: @hide_class}>
          <.live_component
            :let={form}
            module={override_for(@overrides, :sign_in_form_module) || Totp.SignInForm}
            auth_routes_prefix={@auth_routes_prefix}
            id={@sign_in_id}
            strategy={@strategy}
            label={false}
            overrides={@overrides}
            current_tenant={@current_tenant}
            context={@context}
            gettext_fn={@gettext_fn}
          >
            <%= cond do %>
              <% @sign_in_extra != [] -> %>
                <div class={override_for(@overrides, :slot_class)}>
                  {render_slot(@sign_in_extra, form)}
                </div>
              <% true -> %>
            <% end %>

            <div class={override_for(@overrides, :interstitial_class)}>
              <%= if @setup_toggle_enabled? and @setup_enabled? do %>
                <.toggler
                  message={override_for(@overrides, :setup_toggle_text)}
                  show={@setup_id}
                  hide={[@sign_in_id]}
                  overrides={@overrides}
                  gettext_fn={@gettext_fn}
                />
              <% end %>
            </div>
          </.live_component>
        </div>
      <% end %>

      <%= if @setup_enabled? and @setup_toggle_enabled? do %>
        <div id={"#{@setup_id}-wrapper"} class={if @show == :setup, do: nil, else: @hide_class}>
          <.live_component
            :let={form}
            module={override_for(@overrides, :setup_form_module) || Totp.SetupForm}
            auth_routes_prefix={@auth_routes_prefix}
            id={@setup_id}
            strategy={@strategy}
            label={false}
            overrides={@overrides}
            current_tenant={@current_tenant}
            context={@context}
            gettext_fn={@gettext_fn}
          >
            <%= cond do %>
              <% @setup_extra != [] -> %>
                <div class={override_for(@overrides, :slot_class)}>
                  {render_slot(@setup_extra, form)}
                </div>
              <% true -> %>
            <% end %>

            <div class={override_for(@overrides, :interstitial_class)}>
              <%= if @sign_in_toggle_enabled? and @sign_in_enabled? do %>
                <.toggler
                  message={override_for(@overrides, :sign_in_toggle_text)}
                  show={@sign_in_id}
                  hide={[@setup_id]}
                  overrides={@overrides}
                  gettext_fn={@gettext_fn}
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
      {_gettext(@message)}
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
