defmodule Atlas.MixProject do
  use Mix.Project

  def project do
    [
      app: :atlas,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      name: "Atlas",
      description:
        "Atlas is an interactive introspection and visualization tool for Elixir projects, providing navigable graphs and diagrams for frameworks like Ash, Phoenix, and Ecto.",
      source_url: "https://github.com/team-alembic/atlas",
      package: package(),
      dialyzer: [
        plt_add_apps: [:mix]
      ],
      docs: &docs/0
    ]
  end

  defp elixirc_paths(env)
  defp elixirc_paths(:dev), do: ["lib", "dev"]
  defp elixirc_paths(:test), do: ["test/support", "lib", "dev"]
  defp elixirc_paths(_env), do: ["lib"]

  def application do
    [
      extra_applications: [],
      mod: {Atlas.Application, []}
    ]
  end

  defp deps do
    [
      {:ash, "~> 3.5"},
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_view, "~> 1.0"},
      {:earmark, "~> 1.4"},
      {:igniter, "~> 0.6.25", optional: true},
      # UI
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3.1", runtime: Mix.env() == :dev},
      # Development
      {:phx_new, "~> 1.7", only: [:test]},
      {:ex_doc, "~> 0.38.2", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.5", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctest_formatter, "~> 0.4.0", only: [:dev, :test], runtime: false},
      {:phoenix_live_reload, "~> 1.2", only: [:dev, :test]},
      {:picosat_elixir, "~> 0.2.3", only: [:dev, :test]},
      {:plug_cowboy, "~> 2.0", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
      dev: "run --no-halt dev.exs --config config"
    ]
  end

  defp package do
    [
      maintainers: ["Alembic Pty Ltd"],
      files: [
        "lib",
        "LICENSE*",
        "mix.exs",
        "README*"
      ],
      licenses: ["Apache-2.0"],
      links: %{"Github" => "https://github.com/team-alembic/atlas"}
    ]
  end

  defp docs do
    [
      main: "Atlas",
      assets: %{"docs/assets" => "docs/assets"}
    ]
  end
end
