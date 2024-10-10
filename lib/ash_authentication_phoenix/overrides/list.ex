defmodule AshAuthenticationPhoenix.Overrides.List do
  @moduledoc false

  @categorized_overrides [
    "Sign In": [
      AshAuthentication.Phoenix.SignInLive,
      AshAuthentication.Phoenix.Components.SignIn
    ],
    "Password Sign-in": [
      AshAuthentication.Phoenix.Components.Password,
      AshAuthentication.Phoenix.Components.Password.RegisterForm,
      AshAuthentication.Phoenix.Components.Password.SignInForm
    ],
    "Password Reset": [
      AshAuthentication.Phoenix.ResetLive,
      AshAuthentication.Phoenix.Components.Reset,
      AshAuthentication.Phoenix.Components.Reset.Form,
      AshAuthentication.Phoenix.Components.Password.ResetForm
    ],
    Password: [
      AshAuthentication.Phoenix.Components.Password.Input
    ],
    "Magic Link": [
      AshAuthentication.Phoenix.Components.MagicLink
    ],
    OAuth2: [
      AshAuthentication.Phoenix.Components.Apple,
      AshAuthentication.Phoenix.Components.OAuth2
    ],
    Miscellaneous: [
      AshAuthentication.Phoenix.Components.HorizontalRule,
      AshAuthentication.Phoenix.Components.Banner
    ]
  ]

  @overrides @categorized_overrides |> Keyword.values() |> List.flatten()

  @overrides_file "documentation/tutorials/ui-overrides.md"
  @overrides_start_comment "<!-- override-docs-begin -->"
  @overrides_end_comment "<!-- override-docs-end -->"

  @spec overridable() :: list(module())
  @doc false
  def overridable, do: @overrides

  # sobelow_skip ["Traversal.FileModule"]
  @spec write_docs! :: :ok
  @doc false
  def write_docs! do
    [prelude, _ | rest] =
      @overrides_file
      |> File.read!()
      |> String.split([@overrides_start_comment, @overrides_end_comment])

    [prelude, @overrides_start_comment, "\n\n", override_docs(), "\n\n", @overrides_end_comment]
    |> Enum.concat(rest)
    |> Enum.join()
    |> then(&File.write!(@overrides_file, &1))
  end

  defp override_docs do
    Enum.map_join(@categorized_overrides, "\n", fn {category, overrides} ->
      "## #{category}\n#{Enum.map_join(overrides, "\n", &override_doc/1)}"
    end)
  end

  defp override_doc(overridable) do
    """
    ### `#{inspect(overridable)}`

    #{first_line_of_docs(overridable)}

    #{overridable.__overrides__() |> Enum.map_join("\n", &"  * `#{inspect(elem(&1, 0))}` - #{elem(&1, 1)}\n")}
    """
  end

  defp first_line_of_docs(overridable) do
    {:docs_v1, _, _, _, %{"en" => docs}, _, _} = Code.fetch_docs(overridable)

    docs
    |> String.split("\n\n", parts: 2, trim: true)
    |> Enum.at(0)
  end
end
