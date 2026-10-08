defmodule Demo.MixProject do
  use Mix.Project

  def project do
    [
      app: :demo,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      listeners: [Phoenix.CodeReloader, Clarity.CodeReloader],
      consolidate_protocols: Mix.env() != :dev
    ]
  end

  def application do
    [
      mod: {Demo.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:clarity, path: "..", override: true},
      {:ash_diagram, "~> 0.2.2"},
      {:ash, "~> 3.6"},
      {:picosat_elixir, "~> 0.2.3"},
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:bandit, "~> 1.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.4", runtime: Mix.env() == :dev}
    ]
  end
end
