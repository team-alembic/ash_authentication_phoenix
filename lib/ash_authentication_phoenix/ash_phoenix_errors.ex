defimpl AshPhoenix.FormData.Error, for: AshAuthentication.Errors.AuthenticationFailed do
  import PhoenixHTMLHelpers.Form, only: [humanize: 1]

  def to_form_error(error) when is_struct(error.strategy, AshAuthentication.Strategy.Password),
    do: to_auth_failed_error(error)

  def to_form_error(_), do: []

  defp to_auth_failed_error(error)
       when error.strategy.password_field == error.field or is_nil(error.field) do
    [
      {error.strategy.password_field,
       "#{humanize(error.strategy.identity_field)} or #{downcase_humanize(error.strategy.password_field)} was incorrect",
       []}
    ]
  end

  defp to_auth_failed_error(error) do
    [
      {error.field, "#{humanize(error.field)} was incorrect", []}
    ]
  end

  defp downcase_humanize(value) do
    value
    |> humanize()
    |> String.downcase()
  end
end
