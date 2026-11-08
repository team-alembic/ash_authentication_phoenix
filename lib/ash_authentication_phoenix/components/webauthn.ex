# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.WebAuthn do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    hide_class: "CSS class to apply to hide the form that is not showing.",
    interstitial_class: "CSS class for the `div` holding the link to the other form.",
    register_link_text:
      "Text of the link from the sign-in form to registration (or `nil` to disable). Shown only while the strategy allows registration.",
    register_link_class: "CSS class for the link from the sign-in form to registration.",
    sign_in_link_text:
      "Text of the link from the registration form back to sign-in (or `nil` to disable). Shown only while the strategy allows sign-in.",
    sign_in_link_class: "CSS class for the link from the registration form back to sign-in.",
    registration_form_module:
      "The Phoenix component to be used for the registration form. Defaults to `AshAuthentication.Phoenix.Components.WebAuthn.RegistrationForm`.",
    authentication_form_module:
      "The Phoenix component to be used for the authentication form. Defaults to `AshAuthentication.Phoenix.Components.WebAuthn.AuthenticationForm`.",
    slot_class: "CSS class for the `div` surrounding the slot.",
    workflow_root_class:
      "CSS class for the root `div` element in link mode (when `webauthn_path` is configured). Falls back to `root_class` when unset.",
    workflow_button_class:
      "CSS class for the link shown on the sign-in page when `webauthn_path` is configured.",
    workflow_button_text:
      "Text for the link shown on the sign-in page when `webauthn_path` is configured."

  @moduledoc """
  Generates sign in and registration forms for WebAuthn/Passkey authentication.

  One form shows at a time, with a link to the other, the way
  `AshAuthentication.Phoenix.Components.Password` does it:

    * on `live_action: :sign_in` the authentication form, plus a link to
      registration when the strategy allows it;
    * on `live_action: :register` the registration form, plus a link back to
      sign-in.

  With a `register_path` (the `sign_in_route` option) the links navigate
  between the two routes and only the form for the current action is
  rendered. Without one — the dedicated `AshAuthentication.Phoenix.WebAuthnLive`
  page, or a component rendered by hand — both forms are rendered, the other
  one hidden with `hide_class`, and the links toggle between them in the
  browser.

  A strategy that has only one of the two enabled shows that one, whatever
  the action.

  ## Component hierarchy

  This is the top-most strategy-specific component for WebAuthn, nested below
  `AshAuthentication.Phoenix.Components.SignIn`.

  Children:

    * `AshAuthentication.Phoenix.Components.WebAuthn.RegistrationForm`
    * `AshAuthentication.Phoenix.Components.WebAuthn.AuthenticationForm`
    * `AshAuthentication.Phoenix.Components.WebAuthn.Support`

  ## Props

    * `strategy` - The WebAuthn strategy configuration. Required.
    * `live_action` - `:sign_in` (the default) or `:register`.
    * `path` - The sign-in page's path, used by the link back to it.
    * `register_path` - The registration page's path, when the router has
      one.
    * `webauthn_path` - When set, renders a single link to this path rather
      than the full form. Configure via `sign_in_route(webauthn_path: "/webauthn")` and
      mount `webauthn_route/3` at that path to get a dedicated sign-in/register page.
      When `nil` (the default) the full form renders inline as before.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components.WebAuthn, Strategy}
  alias AshAuthentication.Phoenix.WebAuthn, as: PhoenixWebAuthn
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
      # webauthn_path may be a keyword list keyed by subject name — resolve
      # it to this strategy's path (or nil) before the render logic sees it.
      |> assign(
        :webauthn_path,
        PhoenixWebAuthn.resolve_path(Map.get(assigns, :webauthn_path), strategy)
      )
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
    # Both forms finish by exchanging the token the ceremony issued at the
    # strategy's `sign_in_with_token` route, which the strategy only builds
    # while sign-in or verification is on
    # (`AshAuthentication.Strategy.WebAuthn.sign_in_with_token_enabled?/1`).
    # Registration therefore needs that route as well as its own flag.
    strategy = assigns.strategy
    token_exchange? = Strategy.WebAuthn.sign_in_with_token_enabled?(strategy)

    assigns =
      assigns
      |> assign(:sign_in_enabled?, strategy.sign_in_enabled?)
      |> assign(:register_enabled?, token_exchange? and strategy.registration_enabled?)

    link_mode? = assigns.webauthn_path && assigns.live_action != :webauthn

    # The card-style `root_class` suits the dedicated page's full forms; in
    # link mode the single link should sit flush with the other sign-in
    # buttons, so it gets its own (flat) wrapper style.
    root_class =
      if link_mode? do
        override_for(assigns.overrides, :workflow_root_class) ||
          override_for(assigns.overrides, :root_class)
      else
        override_for(assigns.overrides, :root_class)
      end

    # Without a registration route the other form is still rendered, hidden,
    # so the link can show it without leaving the page.
    show = shown_form(assigns)
    toggle? = is_nil(assigns.register_path)

    assigns =
      assign(assigns,
        link_mode?: link_mode?,
        root_class: root_class,
        show: show,
        hide_class: override_for(assigns.overrides, :hide_class),
        render_sign_in?: assigns.sign_in_enabled? && (toggle? || show == :sign_in),
        render_register?: assigns.register_enabled? && (toggle? || show == :register),
        register_link_text: override_for(assigns.overrides, :register_link_text),
        sign_in_link_text: override_for(assigns.overrides, :sign_in_link_text),
        # Both links patch between the routes when there are two, and toggle
        # in the browser otherwise.
        register_link_to: assigns.register_path,
        sign_in_link_to: if(assigns.register_path, do: assigns.path)
      )

    ~H"""
    <div class={@root_class}>
      <%= if @link_mode? do %>
        <.link
          href={@webauthn_path}
          class={override_for(@overrides, :workflow_button_class)}
        >
          {_gettext(override_for(@overrides, :workflow_button_text, "Continue with WebAuthn"))}
        </.link>
      <% else %>
        <.live_component
          module={WebAuthn.Support}
          id={"#{@sign_in_id}-support"}
          overrides={@overrides}
        />

        <%= if @render_sign_in? do %>
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
            >
              <%= if @register_enabled? && @register_link_text do %>
                <div class={override_for(@overrides, :interstitial_class)}>
                  <.other_form_link
                    to={@register_link_to}
                    show={@register_id}
                    hide={@sign_in_id}
                    class={override_for(@overrides, :register_link_class)}
                    text={@register_link_text}
                    gettext_fn={@gettext_fn}
                  />
                </div>
              <% end %>
            </.live_component>
          </div>
        <% end %>

        <%= if @render_register? do %>
          <div
            id={"#{@register_id}-wrapper"}
            class={if @show == :register, do: nil, else: @hide_class}
          >
            <.live_component
              module={
                override_for(@overrides, :registration_form_module) || WebAuthn.RegistrationForm
              }
              id={@register_id}
              strategy={@strategy}
              overrides={@overrides}
              current_tenant={@current_tenant}
              context={@context}
              gettext_fn={@gettext_fn}
              auth_routes_prefix={@auth_routes_prefix}
            >
              <%= if @sign_in_enabled? && @sign_in_link_text do %>
                <div class={override_for(@overrides, :interstitial_class)}>
                  <.other_form_link
                    to={@sign_in_link_to}
                    show={@sign_in_id}
                    hide={@register_id}
                    class={override_for(@overrides, :sign_in_link_class)}
                    text={@sign_in_link_text}
                    gettext_fn={@gettext_fn}
                  />
                </div>
              <% end %>
            </.live_component>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # The form to show: the one the action asks for when the strategy has it,
  # otherwise whichever the strategy does have.
  defp shown_form(%{live_action: :register, register_enabled?: true}), do: :register
  defp shown_form(%{sign_in_enabled?: true}), do: :sign_in
  defp shown_form(%{register_enabled?: true}), do: :register
  defp shown_form(_assigns), do: nil

  # With a route for the other form the link patches to it; without one it
  # swaps the two wrappers in the browser.
  defp other_form_link(%{to: to} = assigns) when is_binary(to) do
    ~H"""
    <.link patch={@to} class={@class}>{_gettext(@text)}</.link>
    """
  end

  defp other_form_link(assigns) do
    ~H"""
    <a href="#" phx-click={toggle_js(@show, @hide)} class={@class}>{_gettext(@text)}</a>
    """
  end

  defp toggle_js(show, hide) do
    show_wrapper = "##{show}-wrapper"

    %JS{}
    |> JS.show(to: show_wrapper)
    |> JS.focus_first(to: show_wrapper)
    |> JS.hide(to: "##{hide}-wrapper")
  end
end
