defmodule AshAuthentication.Phoenix.MixProject do
  @moduledoc false
  use Mix.Project

  @version "1.3.0"

  def project do
    [
      app: :ash_authentication_phoenix,
      version: @version,
      description: "Phoenix integration for Ash Authentication",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      preferred_cli_env: [ci: :test],
      aliases: aliases(),
      deps: deps(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit, :ash_authentication],
        plt_core_path: "priv/plts",
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      docs: [
        main: "readme",
        extras: ["README.md"],
        formatters: ["html"],
        filter_modules: ~r/^Elixir.AshAuthentication.Phoenix/,
        source_url_pattern:
          "https://github.com/team-alembic/ash_authentication_phoenix/blob/main/%{path}#L%{line}",
        groups_for_modules: [
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
          ],
          Internals: ~r/.*/
        ]
      ]
    ]
  end

  def package do
    [
      maintainers: [
        "James Harton <james.harton@alembic.com.au>",
        "Zach Daniel <zach@zachdaniel.dev>"
      ],
      licenses: ["MIT"],
      links: %{
        "Source" => "https://github.com/team-alembic/ash_authentication_phoenix"
      },
      source_url: "https://github.com/team-alembic/ash_authentication_phoenix",
      files: ~w[lib .formatter.exs mix.exs README* LICENSE* CHANGELOG* documentation]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application, do: application(Mix.env())

  def application(:dev) do
    [
      extra_applications: [:logger],
      mod: {Dev.Application, []}
    ]
  end

  def application(_),
    do: [
      extra_applications: [:logger]
    ]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash_authentication, "~> 3.3.1"},
      {:ash_phoenix, "~> 1.1"},
      {:ash, "~> 2.2"},
      {:jason, "~> 1.0"},
      {:phoenix_html, "~> 3.2"},
      {:phoenix_live_view, "~> 0.18"},
      {:phoenix, "~> 1.6"},
      {:bcrypt_elixir, "~> 3.0"},
      {:slugify, "~> 1.3"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.18", only: [:dev, :test]},
      {:elixir_sense, github: "elixir-lsp/elixir_sense", only: [:dev, :test]},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:faker, "~> 0.17.0", only: [:dev, :test]},
      {:git_ops, "~> 2.4", only: [:dev, :test], runtime: false},
      {:mimic, "~> 1.7", only: [:dev, :test]},
      {:plug_cowboy, "~> 2.5", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      ci: [
        "format --check-formatted",
        "doctor --full --raise",
        "credo --strict",
        "dialyzer",
        "hex.audit",
        "test"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "dev"]
  defp elixirc_paths(:dev), do: ["lib", "test/support", "dev"]
  defp elixirc_paths(_), do: ["lib"]
end
