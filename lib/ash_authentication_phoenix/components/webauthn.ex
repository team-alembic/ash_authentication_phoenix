# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.WebAuthn do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    hide_class: "CSS class to apply to hide an element.",
    show_first:
      "The form to show on first load. Either `:sign_in` or `:register`. Only relevant if paths aren't set for them in the router.",
    interstitial_class: "CSS class for the `div` element between the form and the toggle.",
    sign_in_toggle_text:
      "Toggle text to display when the sign in form is not showing (or `nil` to disable).",
    register_toggle_text:
      "Toggle text to display when the register form is not showing (or `nil` to disable).",
    toggler_class: "CSS class for the toggler `a` element.",
    registration_form_module:
      "The Phoenix component to be used for the registration form. Defaults to `AshAuthentication.Phoenix.Components.WebAuthn.RegistrationForm`.",
    authentication_form_module:
      "The Phoenix component to be used for the authentication form. Defaults to `AshAuthentication.Phoenix.Components.WebAuthn.AuthenticationForm`.",
    slot_class: "CSS class for the `div` surrounding the slot."

  @moduledoc """
  Generates sign in and registration forms for WebAuthn/Passkey authentication.

  ## Component hierarchy

  This is the top-most strategy-specific component for WebAuthn, nested below
  `AshAuthentication.Phoenix.Components.SignIn`.

  Children:

    * `AshAuthentication.Phoenix.Components.WebAuthn.RegistrationForm`
    * `AshAuthentication.Phoenix.Components.WebAuthn.AuthenticationForm`
    * `AshAuthentication.Phoenix.Components.WebAuthn.Support`

  ## Props

    * `strategy` - The WebAuthn strategy configuration. Required.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components.WebAuthn, Strategy}
  alias Phoenix.LiveView.{JS, Rendered, Socket}
  import Slug

  @doc false
  @impl true
  def update(assigns, socket) do
    strategy = assigns.strategy

    subject_name =
      strategy.resource
      |> Info.authentication_subject_name!()
      |> to_string()
      |> slugify()

    strategy_name =
      strategy
      |> Strategy.name()
      |> to_string()
      |> slugify()

    socket =
      socket
      |> assign(assigns)
      |> assign(:subject_name, subject_name)
      |> assign(:strategy_name, strategy_name)
      |> assign(:sign_in_id, "#{subject_name}-#{strategy_name}-sign-in")
      |> assign(:register_id, "#{subject_name}-#{strategy_name}-register")
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:live_action, fn -> :sign_in end)
      |> assign_new(:path, fn -> "/" end)
      |> assign_new(:register_path, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:context, fn -> %{} end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    register_enabled? =
      assigns.strategy.registration_enabled? &&
        override_for(assigns.overrides, :register_toggle_text)

    assigns =
      assigns
      |> assign(:hide_class, override_for(assigns.overrides, :hide_class))
      |> assign(:register_enabled?, register_enabled?)
      |> assign(:sign_in_enabled?, !is_nil(override_for(assigns.overrides, :sign_in_toggle_text)))

    show =
      if assigns[:live_action] == :sign_in && is_nil(assigns[:register_path]) do
        assigns[:show_first] || :sign_in
      else
        assigns[:live_action]
      end

    assigns = assign(assigns, :show, show)

    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <.live_component
        module={WebAuthn.Support}
        id={"#{@sign_in_id}-support"}
        overrides={@overrides}
      />

      <div id={"#{@sign_in_id}-wrapper"} class={if @show == :sign_in, do: nil, else: @hide_class}>
        <.live_component
          module={
            override_for(@overrides, :authentication_form_module) || WebAuthn.AuthenticationForm
          }
          id={@sign_in_id}
          strategy={@strategy}
          overrides={@overrides}
          current_tenant={@current_tenant}
          context={@context}
          gettext_fn={@gettext_fn}
          auth_routes_prefix={@auth_routes_prefix}
        />

        <div class={override_for(@overrides, :interstitial_class)}>
          <%= if @register_enabled? do %>
            <.toggler
              message={override_for(@overrides, :register_toggle_text)}
              show={@register_id}
              hide={[@sign_in_id]}
              overrides={@overrides}
              gettext_fn={@gettext_fn}
            />
          <% end %>
        </div>
      </div>

      <%= if @register_enabled? do %>
        <div
          id={"#{@register_id}-wrapper"}
          class={if @live_action == :register, do: nil, else: @hide_class}
        >
          <.live_component
            module={override_for(@overrides, :registration_form_module) || WebAuthn.RegistrationForm}
            id={@register_id}
            strategy={@strategy}
            overrides={@overrides}
            current_tenant={@current_tenant}
            context={@context}
            gettext_fn={@gettext_fn}
            auth_routes_prefix={@auth_routes_prefix}
          />

          <div class={override_for(@overrides, :interstitial_class)}>
            <%= if @sign_in_enabled? do %>
              <.toggler
                message={override_for(@overrides, :sign_in_toggle_text)}
                show={@sign_in_id}
                hide={[@register_id]}
                overrides={@overrides}
                gettext_fn={@gettext_fn}
              />
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
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
