# SPDX-FileCopyrightText: 2024 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Totp.SetupForm do
  unless Code.ensure_loaded?(EQRCode) do
    raise CompileError,
      description: """
      The TOTP setup form requires the `eqrcode` library for QR code generation.

      Please add it to your dependencies in mix.exs:

          {:eqrcode, "~> 0.1"}

      Then run `mix deps.get` to install it.
      """
  end

  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    label_class: "CSS class for the `h2` element.",
    instructions_class: "CSS class for setup instructions text.",
    instructions_text: "Instructions text shown above QR code.",
    qr_code_class: "CSS class for the QR code container.",
    qr_code_wrapper_class: "CSS class for the wrapper around QR code and instructions.",
    form_class: "CSS class for the `form` element.",
    slot_class: "CSS class for the `div` surrounding the slot.",
    button_text: "Text for the submit button.",
    disable_button_text: "Text for the submit button when the request is happening.",
    setup_button_text: "Text for the initial setup button.",
    setup_button_class: "CSS class for the initial setup button.",
    error_class: "CSS class for error messages."

  @moduledoc """
  Generates a setup form for TOTP authentication with QR code display.

  This component handles the complete TOTP setup flow:

  1. Shows a "Set up" button
  2. When clicked, calls the setup action to generate a secret
  3. Displays the QR code and code input field
  4. Validates the code (format only for confirmation mode)
  5. Confirms setup when user submits valid code

  ## Requirements

  This component requires the `eqrcode` library for QR code generation.
  Add it to your dependencies:

      {:eqrcode, "~> 0.1"}

  ## Component hierarchy

  This is a child of `AshAuthentication.Phoenix.Components.Totp`.

  Children:

    * `AshAuthentication.Phoenix.Components.Totp.Input.code_field/1`
    * `AshAuthentication.Phoenix.Components.Totp.Input.submit/1`

  ## Props

    * `strategy` - The configuration map as per
      `AshAuthentication.Info.strategy/2`. Required.
    * `label` - The text to show in the submit label. Generated from the
      configured action name (via `Phoenix.Naming.humanize/1`) if not supplied.
      Set to `false` to disable.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias AshAuthentication.{Info, Phoenix.Components.Totp, Strategy}
  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}

  import AshAuthentication.Phoenix.Components.Helpers,
    only: [auth_path: 5]

  import Phoenix.HTML.Form
  import PhoenixHTMLHelpers.Form
  import Slug

  @type props :: %{
          required(:strategy) => AshAuthentication.Strategy.t(),
          optional(:label) => String.t() | false,
          optional(:current_tenant) => String.t(),
          optional(:context) => map(),
          optional(:auth_routes_prefix) => String.t(),
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }

  @doc false
  @impl true
  @spec update(props, Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    strategy = assigns.strategy
    subject_name = Info.authentication_subject_name!(strategy.resource)

    socket =
      socket
      |> assign(assigns)
      |> assign(subject_name: subject_name)
      |> assign_new(:label, fn -> humanize(strategy.setup_action_name) end)
      |> assign_new(:inner_block, fn -> nil end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:current_tenant, fn -> nil end)
      |> assign_new(:context, fn -> %{} end)
      |> assign_new(:auth_routes_prefix, fn -> nil end)
      |> assign_new(:setup_token, fn -> nil end)
      |> assign_new(:totp_url, fn -> nil end)
      |> assign_new(:qr_svg, fn -> nil end)
      |> assign_new(:code_valid, fn -> nil end)
      |> assign_new(:error, fn -> nil end)

    socket =
      if socket.assigns.setup_token do
        build_confirm_form(socket)
      else
        assign(socket, form: nil, trigger_action: false)
      end

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <%= if @label do %>
        <h2 class={override_for(@overrides, :label_class)}>{_gettext(@label)}</h2>
      <% end %>

      <%= if @error do %>
        <div class={override_for(@overrides, :error_class)}>
          {_gettext(@error)}
        </div>
      <% end %>

      <%= if @setup_token && @qr_svg do %>
        <div class={override_for(@overrides, :qr_code_wrapper_class)}>
          <p class={override_for(@overrides, :instructions_class)}>
            {_gettext(override_for(@overrides, :instructions_text))}
          </p>
          <div class={override_for(@overrides, :qr_code_class)}>
            {Phoenix.HTML.raw(@qr_svg)}
          </div>
        </div>

        <.form
          :let={form}
          for={@form}
          id={@form.id}
          phx-change="change"
          phx-submit="confirm"
          phx-trigger-action={@trigger_action}
          phx-target={@myself}
          action={auth_path(@socket, @subject_name, @auth_routes_prefix, @strategy, :confirm_setup)}
          method="POST"
          class={override_for(@overrides, :form_class)}
        >
          <input type="hidden" name={input_name(form, :setup_token)} value={@setup_token} />

          <Totp.Input.code_field
            strategy={@strategy}
            form={form}
            code_valid={@code_valid}
            overrides={@overrides}
            gettext_fn={@gettext_fn}
          />

          <%= if @inner_block do %>
            <div class={override_for(@overrides, :slot_class)}>
              {render_slot(@inner_block, form)}
            </div>
          <% end %>

          <Totp.Input.submit
            strategy={@strategy}
            id={@form.id <> "-submit"}
            form={form}
            action={:confirm_setup}
            label={override_for(@overrides, :button_text)}
            disable_text={override_for(@overrides, :disable_button_text)}
            overrides={@overrides}
            gettext_fn={@gettext_fn}
          />
        </.form>
      <% else %>
        <button
          type="button"
          phx-click="setup"
          phx-target={@myself}
          class={override_for(@overrides, :setup_button_class)}
        >
          {_gettext(override_for(@overrides, :setup_button_text))}
        </button>
      <% end %>
    </div>
    """
  end

  @doc false
  @impl true
  @spec handle_event(String.t(), %{required(String.t()) => String.t()}, Socket.t()) ::
          {:noreply, Socket.t()}

  def handle_event("setup", _params, socket) do
    strategy = socket.assigns.strategy
    user = socket.assigns[:current_user]

    case call_setup_action(strategy, user, socket.assigns) do
      {:ok, user_with_metadata} ->
        setup_token = Ash.Resource.get_metadata(user_with_metadata, :setup_token)
        totp_url = Ash.Resource.get_metadata(user_with_metadata, :totp_url)
        qr_svg = generate_qr_svg(totp_url)

        socket =
          socket
          |> assign(setup_token: setup_token, totp_url: totp_url, qr_svg: qr_svg, error: nil)
          |> build_confirm_form()

        {:noreply, socket}

      {:error, error} ->
        {:noreply, assign(socket, error: format_error(error))}
    end
  end

  def handle_event("change", params, socket) do
    params = get_params(params, socket.assigns.strategy)
    code = Map.get(params, "code", "")

    code_valid = validate_code_format(code)

    form =
      socket.assigns.form
      |> Form.validate(params, errors: false)

    {:noreply, assign(socket, form: form, code_valid: code_valid)}
  end

  def handle_event("confirm", params, socket) do
    params = get_params(params, socket.assigns.strategy)

    params =
      params
      |> Map.put("setup_token", socket.assigns.setup_token)

    form = Form.validate(socket.assigns.form, params)

    socket =
      socket
      |> assign(:form, form)
      |> assign(:trigger_action, form.valid?)

    {:noreply, socket}
  end

  defp build_confirm_form(socket) do
    strategy = socket.assigns.strategy
    domain = Info.authentication_domain!(strategy.resource)
    subject_name = socket.assigns.subject_name

    context =
      Ash.Helpers.deep_merge_maps(socket.assigns[:context] || %{}, %{
        strategy: strategy,
        private: %{ash_authentication?: true}
      })

    form =
      strategy.resource
      |> Form.for_action(strategy.confirm_setup_action_name,
        domain: domain,
        as: subject_name |> to_string() |> slugify(),
        id:
          "#{subject_name}-#{Strategy.name(strategy)}-#{strategy.confirm_setup_action_name}"
          |> slugify(),
        tenant: socket.assigns[:current_tenant],
        context: context
      )

    assign(socket, form: form, trigger_action: false)
  end

  defp call_setup_action(strategy, user, assigns) when not is_nil(user) do
    options = [
      tenant: assigns[:current_tenant]
    ]

    Strategy.action(strategy, :setup, %{user: user}, options)
  end

  defp call_setup_action(_strategy, nil, _assigns) do
    {:error, "User must be signed in to set up TOTP"}
  end

  defp generate_qr_svg(totp_url) when is_binary(totp_url) do
    totp_url
    |> EQRCode.encode()
    |> EQRCode.svg(width: 200)
  rescue
    _ -> nil
  end

  defp generate_qr_svg(_), do: nil

  defp validate_code_format(code) when is_binary(code) do
    code = String.trim(code)

    cond do
      code == "" -> nil
      Regex.match?(~r/^\d{6}$/, code) -> true
      true -> false
    end
  end

  defp validate_code_format(_), do: nil

  defp get_params(params, strategy) do
    param_key =
      strategy.resource
      |> Info.authentication_subject_name!()
      |> to_string()
      |> slugify()

    Map.get(params, param_key, %{})
  end

  defp format_error(%{message: message}), do: message
  defp format_error(message) when is_binary(message), do: message
  defp format_error(_), do: "An error occurred during setup"
end
