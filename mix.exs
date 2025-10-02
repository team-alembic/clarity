defmodule Clarity.MixProject do
  use Mix.Project

  @version "0.2.0"

  def project do
    [
      app: :clarity,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      aliases: aliases(),
      listeners: [Phoenix.CodeReloader],
      name: "Clarity",
      description:
        "Clarity is an interactive introspection and visualization tool for Elixir projects, providing navigable graphs and diagrams for frameworks like Ash, Phoenix, and Ecto.",
      source_url: "https://github.com/team-alembic/clarity",
      package: package(),
      dialyzer: [
        plt_add_apps: [:mix]
      ],
      test_coverage: [
        ignore_modules: [
          ~r/^Demo\./,
          ~r/^DemoWeb\./,
          ~r/\.Docs$/,
          ~r/^Inspect\.Demo\./,
          ~r/^Clarity\.Test\./,
          Clarity.Web,
          Clarity.CodeReloader,
          Clarity.Vertex
        ]
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
      extra_applications: [:stdlib, :logger],
      mod: {Clarity.Application, []},
      env: [
        clarity_introspectors: [
          Clarity.Introspector.Application,
          Clarity.Introspector.Module,
          Clarity.Introspector.Spark.Dsl,
          Clarity.Introspector.Spark.Extension,
          Clarity.Introspector.Spark.Section,
          Clarity.Introspector.Spark.Entity,
          Clarity.Introspector.Ash.Domain,
          Clarity.Introspector.Ash.Resource,
          Clarity.Introspector.Ash.DataLayer,
          Clarity.Introspector.Ash.Spark,
          Clarity.Introspector.Ash.Type,
          Clarity.Introspector.Phoenix.Endpoint,
          Clarity.Introspector.Phoenix.Router
        ],
        clarity_perspective_lensmakers: [
          Clarity.Perspective.Lensmaker.Architect,
          Clarity.Perspective.Lensmaker.Security,
          Clarity.Perspective.Lensmaker.Debug
        ],
        clarity_content_providers: [
          Clarity.Content.Graph,
          Clarity.Content.Moduledoc,
          Clarity.Content.Ash.DomainOverview,
          Clarity.Content.Ash.ResourceOverview
        ],
        default_perspective_lens: "architect"
      ]
    ]
  end

  defp deps do
    [
      {:usage_rules, "~> 0.1", only: [:dev]},
      {:ash, "~> 3.5 and >= 3.5.43", optional: true},
      {:spark, "~> 2.3", optional: true},
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_view, "~> 1.0"},
      {:earmark, "~> 1.4"},
      {:telemetry, "~> 1.3"},
      {:telemetry_registry, "~> 0.3.2"},
      {:igniter, "~> 0.6.25", optional: true},
      # UI
      {:esbuild, "~> 0.8", only: [:dev, :test], runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.4.0", only: [:dev, :test], runtime: Mix.env() == :dev},
      # Development
      {:phx_new, "~> 1.7", only: [:test]},
      {:ex_doc, "~> 0.38.2", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.5", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctest_formatter, "~> 0.4.0", only: [:dev, :test], runtime: false},
      {:phoenix_live_reload, "~> 1.2", only: [:dev, :test]},
      {:picosat_elixir, "~> 0.2.3", only: [:dev, :test]},
      {:plug_cowboy, "~> 2.0", only: [:dev, :test]},
      {:floki, ">= 0.30.0", only: [:test]},
      {:lazy_html, ">= 0.1.0", only: [:test]},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.18", only: [:dev, :test]},
      {:ex_check, "~> 0.15", only: [:dev, :test]},
      {:git_ops, "~> 2.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default --sourcemap=inline"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
      dev: "run --no-halt --no-start dev.exs --config config",
      "usage_rules.update": [
        String.trim("""
        usage_rules.sync CLAUDE.md --all \
          --inline usage_rules:all \
          --link-to-folder deps \
          --remove-missing \
          --link-style at
        """)
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Alembic Pty Ltd"],
      files: [
        "lib",
        "priv",
        "LICENSE*",
        "mix.exs",
        ".formatter.exs",
        "README*"
      ],
      licenses: ["Apache-2.0"],
      links: %{"Github" => "https://github.com/team-alembic/clarity"}
    ]
  end

  defp docs do
    [
      main: "Clarity",
      logo: "priv/static/images/logo.svg",
      assets: %{"docs/assets" => "docs/assets", "priv/static/images" => "priv/static/images"},
      source_ref: "v#{@version}",
      nesting: [Clarity.Perspective, Clarity.Vertex],
      groups_for_modules: [
        Perspective: [
          ~r/^Clarity\.Perspective/
        ],
        Graph: [
          ~r/^Clarity\.Graph/
        ],
        "Vertex Protocols": [
          Clarity.Vertex,
          ~r/^Clarity\.Vertex\.(.+)Provider$/
        ],
        Vertices: [
          ~r/^Clarity\.Vertex(?!\.(Ash|Spark|Phoenix))/
        ],
        Content: [
          ~r/^Clarity\.Content/
        ],
        Components: [
          ~r/^Clarity\..+Component/
        ],
        "Ash Integration": [
          ~r/\.Ash\./
        ],
        "Spark Integration": [
          ~r/\.Spark\./
        ],
        "Phoenix Integration": [
          ~r/\.Phoenix\./
        ]
      ]
    ]
  end
end
