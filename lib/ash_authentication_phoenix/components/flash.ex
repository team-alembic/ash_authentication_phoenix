# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.Flash do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    message_class_info: "CSS class for the message `div` element when the flash key is `:info`.",
    message_class_error: "CSS class for the message `div` element when the flash key is `:error`."

  @moduledoc """
  Renders the [Phoenix flash messages](https://hexdocs.pm/phoenix/controllers.html#flash-messages)
  set by Ash Authentication Phoenix.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}

  ## Props

      * `overrides` - A list of override modules.
  """
  use AshAuthentication.Phoenix.Web, :live_component
  alias Phoenix.LiveView.Rendered

  @type props :: %{
          optional(:overrides) => [module]
        }

  @doc false
  @impl true
  @spec render(props) :: Rendered.t() | no_return
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)

    ~H"""
    <div>
      <div
        :if={Phoenix.Flash.get(@flash, :info)}
        class={override_for(@overrides, :message_class_info)}
        role="alert"
        phx-click="lv:clear-flash"
        phx-value-key="info"
      >
        {Phoenix.Flash.get(@flash, :info)}
      </div>
      <div
        :if={Phoenix.Flash.get(@flash, :error)}
        class={override_for(@overrides, :message_class_error)}
        role="alert"
        phx-click="lv:clear-flash"
        phx-value-key="error"
      >
        {Phoenix.Flash.get(@flash, :error)}
      </div>
    </div>
    """
  end
end
