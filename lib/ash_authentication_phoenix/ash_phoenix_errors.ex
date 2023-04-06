defimpl AshPhoenix.FormData.Error, for: AshAuthentication.Errors.AuthenticationFailed do
  import Phoenix.HTML.Form, only: [humanize: 1]

  def to_form_error(error) when is_struct(error.strategy, AshAuthentication.Strategy.Password) do
    [
      {error.strategy.password_field,
       "#{humanize(error.strategy.identity_field)} or #{downcase_humanize(error.strategy.password_field)} was incorrect",
       []}
    ]
  end

  def to_form_error(_), do: []

  defp downcase_humanize(value) do
    value
    |> humanize()
    |> String.downcase()
  end
end
