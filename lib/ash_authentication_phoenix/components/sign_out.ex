# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.SignOut do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    root_class: "CSS class for the root `div` element.",
    h2_class: "CSS class for the heading.",
    h2_text: "Heading text.",
    info_text: "Informational text displayed below the heading.",
    info_text_class: "CSS class for the informational text.",
    form_class: "CSS class for the form element.",
    button_text: "Text for the sign-out button.",
    button_class: "CSS class for the sign-out button."

  @moduledoc """
  Renders a sign-out confirmation form.

  The form submits a DELETE request to the sign-out controller action,
  ensuring CSRF protection against logout CSRF attacks.

  ## Props

    * `sign_out_path` - The path to submit the sign-out form to.
    * `overrides` - A list of override modules.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :live_component
  alias Phoenix.LiveView.{Rendered, Socket}

  @type props :: %{
          required(:sign_out_path) => String.t(),
          optional(:overrides) => [module]
        }

  @doc false
  @impl true
  @spec update(props, Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t()
  def render(assigns) do
    ~H"""
    <div class={override_for(@overrides, :root_class)}>
      <h2 class={override_for(@overrides, :h2_class)}>
        {override_for(@overrides, :h2_text)}
      </h2>
      <p :if={override_for(@overrides, :info_text)} class={override_for(@overrides, :info_text_class)}>
        {override_for(@overrides, :info_text)}
      </p>
      <.form
        for={%{}}
        action={@sign_out_path}
        method="delete"
        class={override_for(@overrides, :form_class)}
      >
        <button type="submit" class={override_for(@overrides, :button_class)}>
          {override_for(@overrides, :button_text)}
        </button>
      </.form>
    </div>
    """
  end
end
