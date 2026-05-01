# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Otp do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    request_form_module:
      "The Phoenix component used for the request (step one) form. Defaults to `AshAuthentication.Phoenix.Components.Otp.RequestForm`.",
    verify_form_module:
      "The Phoenix component used for the verify (step two) form. Defaults to `AshAuthentication.Phoenix.Components.Otp.VerifyForm`."

  @moduledoc """
  Generates a sign-in form for the OTP strategy.

  The OTP flow is two steps on the same page:

    1. The user submits their identity (e.g. email). The strategy fires the
       configured sender, which delivers a short code out-of-band.
    2. The user enters the code they received and submits. This component
       posts the code to the strategy's sign-in endpoint via
       `phx-trigger-action`, so the JWT lands in the session through the
       standard `AuthController` pipeline.

  ## Component hierarchy

  This is the top-most strategy-specific component for OTP, nested below
  `AshAuthentication.Phoenix.Components.SignIn`.

  Children:

    * `AshAuthentication.Phoenix.Components.Otp.RequestForm`
    * `AshAuthentication.Phoenix.Components.Otp.VerifyForm`

  ## Props

    * `strategy` - The OTP strategy configuration as per
      `AshAuthentication.Info.strategy/2`. Required.
    * `auth_routes_prefix` - Optional prefix for authentication routes.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components.Otp, Strategy}
  alias Phoenix.LiveView.{Rendered, Socket}
  import Slug

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          optional(:auth_routes_prefix) => String.t(),
          optional(:current_tenant) => String.t(),
          optional(:context) => map(),
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }

  @doc false
  @impl true
  @spec update(map, Socket.t()) :: {:ok, Socket.t()}
  def update(%{event: :request_succeeded, identity: identity}, socket) do
    {:ok,
     socket
     |> assign(:phase, :verify)
     |> assign(:identity, identity)}
  end

  def update(%{event: :reset_to_request}, socket) do
    {:ok,
     socket
     |> assign(:phase, :request)
     |> assign(:identity, nil)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:phase, fn -> :request end)
      |> assign_new(:identity, fn -> nil end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:context, fn -> %{} end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(props) :: Rendered.t() | no_return
  def render(assigns) do
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

    request_id = "#{subject_name}-#{strategy_name}-request"
    verify_id = "#{subject_name}-#{strategy_name}-verify"

    assigns =
      assigns
      |> assign(:request_id, request_id)
      |> assign(:verify_id, verify_id)

    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= if @phase == :request do %>
        <.live_component
          module={override_for(@overrides, :request_form_module) || Otp.RequestForm}
          id={@request_id}
          parent_id={@id}
          strategy={@strategy}
          overrides={@overrides}
          current_tenant={@current_tenant}
          context={@context}
          gettext_fn={@gettext_fn}
        />
      <% else %>
        <.live_component
          module={override_for(@overrides, :verify_form_module) || Otp.VerifyForm}
          id={@verify_id}
          parent_id={@id}
          strategy={@strategy}
          identity={@identity}
          auth_routes_prefix={@auth_routes_prefix}
          overrides={@overrides}
          current_tenant={@current_tenant}
          context={@context}
          gettext_fn={@gettext_fn}
        />
      <% end %>
    </div>
    """
  end
end
