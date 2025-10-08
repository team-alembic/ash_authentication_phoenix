# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.MagicLink.Input do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    submit_label:
      "A function that takes the strategy and returns text for the sign in button, or a string.",
    submit_class: "CSS class for the form submit `input` element."

  @moduledoc """
  Function components for dealing with form input during magic link sign in.

  ## Component hierarchy

  These function components are consumed by
  `AshAuthentication.Phoenix.Components.MagicLink.Form`

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :component
  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}
  import PhoenixHTMLHelpers.Form

  @doc """
  Generate an form submit button.

  ## Props

    * `socket` - Phoenix LiveView socket.  This is needed to be able to retrieve
      the correct CSS configuration.  Required.
    * `strategy` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.  Required.
    * `form` - An `AshPhoenix.Form`.  Required.
    * `submit_label` - The text to show in the submit label.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.
  """
  @spec submit(%{
          required(:socket) => Socket.t(),
          required(:form) => Form.t(),
          optional(:submit_label) => String.t(),
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }) :: Rendered.t() | no_return
  def submit(assigns) do
    assigns =
      assigns
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:submit_label, fn ->
        fn _ -> override_for(assigns.overrides, :submit_label) end
      end)
      |> assign_new(:disable_text, fn -> nil end)
      |> update(:submit_label, fn submit_label ->
        if is_function(submit_label) do
          submit_label.(assigns.strategy)
        else
          submit_label
        end
      end)

    ~H"""
    {submit(_gettext(@submit_label),
      class: override_for(@overrides, :submit_class),
      phx_disable_with: _gettext(@disable_text)
    )}
    """
  end
end
