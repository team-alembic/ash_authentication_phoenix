defmodule AshAuthentication.Phoenix.Test.Gettext do
  @moduledoc """
  Gettext stub,
  referenced in AshAuthentication.Phoenix.Test.Router
  """
  use Gettext.Backend, otp_app: :ash_authentication_phoenix

  @spec translate_test(String.t(), keyword) :: String.t()
  def translate_test(_msgid, _bindings) do
    "Never gonna give you up!"
  end

  @impl true
  def handle_missing_translation(_locale, _domain, _msgctxt, _msgid, _bindings),
    do: {:ok, translate_test("_", [])}
end
