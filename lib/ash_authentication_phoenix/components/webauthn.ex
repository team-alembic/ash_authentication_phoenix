# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.WebAuthn do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    registration_form_module:
      "The Phoenix component to be used for the registration form. Defaults to `AshAuthentication.Phoenix.Components.WebAuthn.RegistrationForm`.",
    authentication_form_module:
      "The Phoenix component to be used for the authentication form. Defaults to `AshAuthentication.Phoenix.Components.WebAuthn.AuthenticationForm`.",
    slot_class: "CSS class for the `div` surrounding the slot.",
    workflow_button_class:
      "CSS class for the link shown on the sign-in page when `webauthn_path` is configured.",
    workflow_button_text:
      "Text for the link shown on the sign-in page when `webauthn_path` is configured."

  @moduledoc """
  Generates sign in and registration forms for WebAuthn/Passkey authentication.

  ## Component hierarchy

  This is the top-most strategy-specific component for WebAuthn, nested below
  `AshAuthentication.Phoenix.Components.SignIn`.

  Children:

    * `AshAuthentication.Phoenix.Components.WebAuthn.RegistrationForm`
    * `AshAuthentication.Phoenix.Components.WebAuthn.AuthenticationForm`
    * `AshAuthentication.Phoenix.Components.WebAuthn.Support`
    * `AshAuthentication.Phoenix.Components.HorizontalRule` (between the two forms)

  ## Props

    * `strategy` - The WebAuthn strategy configuration. Required.
    * `webauthn_path` - When set, renders a single link to this path rather than
      the full form. Configure via `sign_in_route(webauthn_path: "/webauthn")` and
      mount `webauthn_route/3` at that path to get a dedicated sign-in/register page.
      When `nil` (the default) the full form renders inline as before.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components, Phoenix.Components.WebAuthn, Strategy}
  alias Phoenix.LiveView.{Rendered, Socket}
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
      |> assign_new(:webauthn_path, fn -> nil end)
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
    assigns = assign(assigns, :register_enabled?, assigns.strategy.registration_enabled?)

    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= if @webauthn_path && @live_action != :webauthn do %>
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

        <%= if @register_enabled? do %>
          <.live_component
            module={Components.HorizontalRule}
            id={"#{@sign_in_id}-divider"}
            overrides={@overrides}
          />

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
        <% end %>
      <% end %>
    </div>
    """
  end
end
