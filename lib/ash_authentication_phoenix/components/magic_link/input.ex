# SPDX-FileCopyrightText: 2022 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.MagicLink.Input do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    submit_label:
      "A function that takes the strategy and returns text for the sign in button, or a string.",
    input_debounce: "Number of milliseconds to debounce input by (or `nil` to disable).",
    remember_me_class: "CSS class for the `div` element surrounding the remember me field.",
    remember_me_input_label: "Label for remember me field.",
    checkbox_class: "CSS class for the `input` element of the remember me field.",
    checkbox_label_class: "CSS class for the `label` element of the remember me field.",
    submit_class: "CSS class for the form submit `input` element."

  @moduledoc """
  Function components for dealing with form input during magic link sign in.

  ## Component hierarchy

  These function components are consumed by
  `AshAuthentication.Phoenix.Components.MagicLink.Form`

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :component
  alias AshAuthentication.Strategy
  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}
  import PhoenixHTMLHelpers.Form
  import Phoenix.HTML.Form

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

  @doc """
  Generate a form field for the remember me field.

  ## Props

    * `socket` - Phoenix LiveView socket.  This is needed to be able to retrieve
      the correct CSS configuration.  Required.
    * `strategy` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.  Required.
    * `form` - An `AshPhoenix.Form`.  Required.
    * `name` - The name of the field.  Defaults to `:remember_me`.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.
  """
  @spec remember_me_field(%{
          required(:socket) => Socket.t(),
          required(:strategy) => Strategy.t(),
          required(:form) => Form.t(),
          optional(:name) => atom,
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }) :: Rendered.t() | no_return
  def remember_me_field(assigns) do
    assigns =
      assigns
      |> assign_new(:name, fn -> :remember_me end)
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:checkbox_class, fn -> override_for(assigns.overrides, :checkbox_class) end)
      |> assign_new(:checkbox_label_class, fn ->
        override_for(assigns.overrides, :checkbox_label_class)
      end)

    ~H"""
    <div class={override_for(@overrides, :remember_me_class)}>
      {checkbox(@form, @name,
        class: @checkbox_class,
        value: input_value(@form, @name),
        phx_debounce: override_for(@overrides, :input_debounce)
      )}
      {label(
        @form,
        @name,
        _gettext(override_for(@overrides, :remember_me_input_label)),
        class: override_for(@overrides, :checkbox_label_class)
      )}
    </div>
    """
  end
end
