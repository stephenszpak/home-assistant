defmodule HomeAssistantUmbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      deps: [],
      version: "0.1.0",
      elixir: "~> 1.17",
      preferred_cli_env: [
        test: :test
      ]
    ]
  end

  def deps do
    []
  end
end

