defmodule AshAuthentication.Phoenix.SparkDocIndex do
  @moduledoc false

  use Spark.DocIndex, otp_app: :ash_authentication_phoenix, guides_from: ["documentation/**/*.md"]

  @doc false
  @impl true
  @spec for_library :: String.t()
  def for_library, do: "ash_authentication_phoenix"

  @doc false
  @impl true
  @spec extensions :: [Spark.DocIndex.extension()]
  def extensions do
    []
  end

  @doc false
  @impl true
  @spec mix_tasks :: [{String.t(), [module]}]
  def mix_tasks, do: []

  @doc false
  @impl true
  def code_modules do
    [
      Welcome: [
        AshAuthentication.Phoenix
      ],
      "Routing and Controller": [
        AshAuthentication.Phoenix.Controller,
        AshAuthentication.Phoenix.Plug,
        AshAuthentication.Phoenix.Router
      ],
      Customisation: [
        AshAuthentication.Phoenix.Overrides,
        AshAuthentication.Phoenix.Overrides.Default
      ],
      Components: [
        AshAuthentication.Phoenix.SignInLive,
        AshAuthentication.Phoenix.Components.SignIn,
        AshAuthentication.Phoenix.Components.OAuth2,
        AshAuthentication.Phoenix.Components.Password,
        AshAuthentication.Phoenix.Components.Password.SignInForm,
        AshAuthentication.Phoenix.Components.Password.RegisterForm,
        AshAuthentication.Phoenix.Components.Password.Input
      ]
    ]
  end
end
