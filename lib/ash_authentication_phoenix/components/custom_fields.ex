# SPDX-FileCopyrightText: 2026 Alembic Pty Ltd
#
# SPDX-License-Identifier: MIT

defmodule AshAuthentication.Phoenix.Components.CustomFields do
  use AshAuthentication.Phoenix.Overrides.Overridable,
    field_class: "CSS class for `div` elements surrounding the fields.",
    label_class: "CSS class for `label` elements.",
    input_class: "CSS class for text-like `input` elements.",
    input_class_with_error:
      "CSS class for text-like `input` elements when there is a validation error.",
    checkbox_class: "CSS class for checkbox `input` elements.",
    select_class: "CSS class for `select` elements.",
    error_ul: "CSS class for the `ul` element on error lists.",
    error_li: "CSS class for the `li` elements on error lists.",
    input_debounce: "Number of milliseconds to debounce input by (or `nil` to disable).",
    field_labels:
      "A map of field name (atom) to label text, e.g. `%{name: \"Full name\"}`. Fields not in the map fall back to the humanized field name.",
    field_placeholders: "A map of field name (atom) to placeholder text.",
    field_input_types:
      "A map of field name (atom) to HTML input type (e.g. `%{ssn: :password, phone: :tel}`), overriding the type derived from the attribute definition."

  @moduledoc """
  Automatically rendered inputs for custom registration fields.

  Strategies which support the `register_action_accept` DSL option (password
  and WebAuthn) let you accept additional writable attributes in their
  generated register action. The registration form components use `field/1`
  to render an appropriately-typed input for each of those attributes, as
  resolved by `AshAuthentication.Strategy.CustomFields.register_fields/1`.

  The input type is derived from the attribute definition:

  | Attribute                           | Input                    |
  |-------------------------------------|--------------------------|
  | confirmed with `secret?: true`      | `password`               |
  | `:boolean`                          | `checkbox`               |
  | `:integer`, `:decimal`, `:float`    | `number`                 |
  | `:date`                             | `date`                   |
  | `:time`                             | `time`                   |
  | `:utc_datetime(_usec)`, `:naive_datetime` | `datetime-local`   |
  | `:atom` with `one_of` constraints   | `select`                 |
  | `:string`/`:ci_string` named like an email | `email`           |
  | anything else                       | `text`                   |

  ## Sensitive fields

  `sensitive?` marks an attribute for log redaction — commonly PII, such as
  personal names — which doesn't imply the input should be masked. Masking
  is therefore never inferred: a `sensitive? true` field must carry an
  explicit confirmation via a `secret?` entry in the strategy's
  `register_action_accept` (e.g. `[given_names: [secret?: false]]`, or
  `secret?: true` to render a masked password input). Rendering a sensitive
  field without that confirmation raises. See
  `AshAuthentication.Strategy.CustomFields` for details.

  The `field_input_types` override can still force a specific input type per
  field when the derivation gets it wrong, e.g.
  `set :field_input_types, %{phone: :tel}` — an entry there also counts as
  an explicit decision for a sensitive field.

  Validation errors come from the register action's changeset as usual —
  `allow_nil?`, constraints, and validations declared on the resource all
  apply. String `min_length`/`max_length` and number `min`/`max` constraints
  are additionally mirrored onto the input element as HTML attributes.

  #{AshAuthentication.Phoenix.Overrides.Overridable.generate_docs()}
  """

  use AshAuthentication.Phoenix.Web, :component
  alias Ash.Resource.Attribute
  alias AshPhoenix.Form
  alias Phoenix.LiveView.Rendered
  import Phoenix.HTML.Form
  import PhoenixHTMLHelpers.Form

  @doc """
  Renders a label, input, and errors for a single custom field.

  ## Props

    * `form` - An `AshPhoenix.Form`. Required.
    * `attribute` - The `Ash.Resource.Attribute` to render an input for.
      Required.
    * `secret?` - The strategy's `secret?` confirmation for the field.
      Required (and enforced) when the attribute is `sensitive? true`;
      `true` renders a masked password input.
    * `overrides` - A list of override modules.
    * `gettext_fn` - Optional text translation function.
  """
  @spec field(%{
          required(:form) => Form.t(),
          required(:attribute) => Attribute.t(),
          optional(:secret?) => boolean,
          optional(:overrides) => [module],
          optional(:gettext_fn) => {module, atom}
        }) :: Rendered.t() | no_return
  def field(assigns) do
    attribute = assigns.attribute

    assigns =
      assigns
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:secret?, fn -> nil end)
      |> assign(:name, attribute.name)
      |> assign(:required?, !attribute.allow_nil?)
      |> assign(:constraint_attrs, constraint_attrs(attribute))

    assigns =
      assign(assigns, :input_type, resolve_input_type(assigns, attribute))

    assigns =
      assigns
      |> assign(
        :label_text,
        override_for(assigns.overrides, :field_labels, %{})[attribute.name] ||
          humanize(attribute.name)
      )
      |> assign(
        :placeholder,
        override_for(assigns.overrides, :field_placeholders, %{})[attribute.name]
      )
      |> assign(:input_class, input_class(assigns, attribute.name))

    ~H"""
    <div class={override_for(@overrides, :field_class)}>
      <%= case @input_type do %>
        <% :checkbox -> %>
          {label @form, @name, class: override_for(@overrides, :label_class) do
            [
              checkbox(@form, @name, class: override_for(@overrides, :checkbox_class)),
              _gettext(@label_text)
            ]
          end}
        <% {:select, options} -> %>
          {label(@form, @name, _gettext(@label_text), class: override_for(@overrides, :label_class))}
          {select(@form, @name, options,
            class: override_for(@overrides, :select_class),
            prompt: if(@required?, do: nil, else: ""),
            required: @required?
          )}
        <% input_type -> %>
          {label(@form, @name, _gettext(@label_text), class: override_for(@overrides, :label_class))}
          {text_input(
            @form,
            @name,
            [
              type: to_string(input_type),
              class: @input_class,
              phx_debounce: override_for(@overrides, :input_debounce),
              placeholder: @placeholder && _gettext(@placeholder),
              required: @required?
            ] ++ @constraint_attrs
          )}
      <% end %>
      <.error form={@form} field={@name} overrides={@overrides} gettext_fn={@gettext_fn} />
    </div>
    """
  end

  @doc false
  @spec error(map) :: Rendered.t()
  def error(assigns) do
    assigns =
      assigns
      |> assign_new(:overrides, fn -> [AshAuthentication.Phoenix.Overrides.Default] end)
      |> assign_new(:gettext_fn, fn -> nil end)
      |> assign_new(:errors, fn ->
        assigns.form
        |> Form.errors()
        |> Keyword.get_values(assigns.field)
      end)

    ~H"""
    <%= if Enum.any?(@errors) do %>
      <ul class={override_for(@overrides, :error_ul)}>
        <%= for error <- @errors do %>
          <li class={override_for(@overrides, :error_li)} phx-feedback-for={input_name(@form, @field)}>
            {_gettext(error)}
          </li>
        <% end %>
      </ul>
    <% end %>
    """
  end

  defp input_class(assigns, field) do
    if has_error?(assigns.form, field) do
      override_for(assigns.overrides, :input_class_with_error)
    else
      override_for(assigns.overrides, :input_class)
    end
  end

  defp has_error?(form, field) do
    form
    |> Form.errors()
    |> Keyword.has_key?(field)
  end

  defp resolve_input_type(assigns, attribute) do
    forced_type = override_for(assigns.overrides, :field_input_types, %{})[attribute.name]

    cond do
      forced_type -> forced_type
      assigns[:secret?] == true -> :password
      attribute.sensitive? && not is_boolean(assigns[:secret?]) -> raise_unconfirmed!(attribute)
      true -> derived_input_type(attribute)
    end
  end

  @spec raise_unconfirmed!(Attribute.t()) :: no_return
  defp raise_unconfirmed!(attribute) do
    raise ArgumentError, """
    The custom field `#{inspect(attribute.name)}` is marked `sensitive?: true`, \
    but no `secret?` confirmation was given.

    `sensitive?` redacts the value from logs and is commonly used for PII, \
    which doesn't imply the input should be masked. Confirm the intent in the \
    strategy's `register_action_accept`:

        register_action_accept [#{attribute.name}: [secret?: false]]

    Use `secret?: true` if the input should be masked (rendered as a password \
    field), or `secret?: false` for a regular input.
    """
  end

  defp derived_input_type(attribute) do
    case Ash.Type.get_type(attribute.type) do
      Ash.Type.Boolean ->
        :checkbox

      type when type in [Ash.Type.Integer, Ash.Type.Decimal, Ash.Type.Float] ->
        :number

      Ash.Type.Date ->
        :date

      Ash.Type.Time ->
        :time

      type
      when type in [Ash.Type.UtcDatetime, Ash.Type.UtcDatetimeUsec, Ash.Type.NaiveDatetime] ->
        :"datetime-local"

      Ash.Type.Atom ->
        case attribute.constraints[:one_of] do
          nil -> :text
          options -> {:select, Enum.map(options, &{humanize(&1), &1})}
        end

      type when type in [Ash.Type.String, Ash.Type.CiString] ->
        if attribute.name |> to_string() |> String.contains?("email"),
          do: :email,
          else: :text

      _other ->
        :text
    end
  end

  defp constraint_attrs(attribute) do
    case Ash.Type.get_type(attribute.type) do
      type when type in [Ash.Type.String, Ash.Type.CiString] ->
        reject_nil_attrs(
          minlength: attribute.constraints[:min_length],
          maxlength: attribute.constraints[:max_length]
        )

      type when type in [Ash.Type.Integer, Ash.Type.Decimal, Ash.Type.Float] ->
        reject_nil_attrs(
          min: attribute.constraints[:min],
          max: attribute.constraints[:max]
        )

      _other ->
        []
    end
  end

  defp reject_nil_attrs(attrs), do: Enum.reject(attrs, fn {_, value} -> is_nil(value) end)
end
