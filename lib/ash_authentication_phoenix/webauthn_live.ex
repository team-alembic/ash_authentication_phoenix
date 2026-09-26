# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.WebAuthnLive do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the outer full-page `div` element.",
    inner_class: "CSS class for the inner column-width `div` element."

  @moduledoc """
  Dedicated WebAuthn sign-in and registration page.

  Mount this with `webauthn_route/3` in your router to provide a standalone
  passkey page. Pair it with `sign_in_route(webauthn_path: "/webauthn")` to
  show a "Continue with WebAuthn" link on the main sign-in page instead of
  embedding the full form there.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_view

  alias AshAuthentication.Info
  alias AshAuthentication.Phoenix.Components
  alias AshAuthentication.Strategy
  alias Phoenix.LiveView.{Rendered, Socket}
  import Slug

  @doc false
  @impl true
  def mount(_params, session, socket) do
    resource = session["resource"]
    strategy_name = session["strategy"]

    strategy = Info.strategy!(resource, strategy_name)

    subject_name =
      resource
      |> Info.authentication_subject_name!()
      |> to_string()
      |> slugify()

    strategy_name_slug =
      strategy
      |> Strategy.name()
      |> to_string()
      |> slugify()

    socket =
      socket
      |> assign(:strategy, strategy)
      |> assign(:subject_name, subject_name)
      |> assign(:strategy_name_slug, strategy_name_slug)
      |> assign(:path, session["path"] || "/")
      |> assign(:context, session["context"] || %{})
      |> assign(:overrides, session["overrides"] || [AshAuthentication.Phoenix.Overrides.Default])
      |> assign(:auth_routes_prefix, session["auth_routes_prefix"])
      |> assign(:gettext_fn, session["gettext_fn"])
      |> assign(:current_tenant, session["tenant"])
      |> assign(:live_action, :webauthn)

    {:ok, socket}
  end

  @doc """
  Forwards timeout messages from the nested RegistrationForm/AuthenticationForm
  components.  The components use `Process.send_after` which delivers to this
  LiveView's PID, so we relay via `send_update/2` to the correct child component.
  """
  @impl Phoenix.LiveView
  def handle_info({:passkeys_supported, _}, socket), do: {:noreply, socket}
  def handle_info({:conditional_ui_available, _}, socket), do: {:noreply, socket}

  def handle_info(:registration_timeout, socket) do
    id = "#{socket.assigns.subject_name}-#{socket.assigns.strategy_name_slug}-register"

    send_update(Components.WebAuthn.RegistrationForm,
      id: id,
      submitting: false,
      error_message: "Registration timed out. Please try again."
    )

    {:noreply, socket}
  end

  def handle_info(:authentication_timeout, socket) do
    id = "#{socket.assigns.subject_name}-#{socket.assigns.strategy_name_slug}-sign-in"

    send_update(Components.WebAuthn.AuthenticationForm,
      id: id,
      submitting: false,
      error_message: "Authentication timed out. Please try again."
    )

    {:noreply, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <div class={override_for(@overrides, :inner_class)}>
        <.live_component
          module={Components.WebAuthn}
          id={"webauthn-#{AshAuthentication.Strategy.name(@strategy)}"}
          strategy={@strategy}
          path={@path}
          auth_routes_prefix={@auth_routes_prefix}
          current_tenant={@current_tenant}
          context={@context}
          live_action={@live_action}
          overrides={@overrides}
          gettext_fn={@gettext_fn}
        />
      </div>
    </div>
    """
  end
end
