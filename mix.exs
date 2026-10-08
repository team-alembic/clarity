defmodule Clarity.MixProject do
  use Mix.Project

  @version "0.6.0"

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
  defp elixirc_paths(:test), do: ["test/support", "lib", "demo/lib"]
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
          Clarity.Introspector.Reactor,
          Clarity.Introspector.Phoenix.Endpoint,
          Clarity.Introspector.Phoenix.Router,
          Clarity.Introspector.Advisory
        ],
        clarity_perspective_lensmakers: [
          Clarity.Perspective.Lensmaker.Architect,
          Clarity.Perspective.Lensmaker.Security,
          Clarity.Perspective.Lensmaker.Documentation,
          Clarity.Perspective.Lensmaker.GraphNavigation,
          Clarity.Perspective.Lensmaker.Debug
        ],
        clarity_content_providers: [
          Clarity.Content.Graph,
          Clarity.Content.Moduledoc,
          Clarity.Content.Ash.ApplicationOverview,
          Clarity.Content.Ash.DomainOverview,
          Clarity.Content.Ash.ResourceOverview,
          Clarity.Content.Ash.ActionOverview,
          Clarity.Content.Ash.AttributeOverview,
          Clarity.Content.Ash.CalculationOverview,
          Clarity.Content.Ash.AggregateOverview,
          Clarity.Content.Ash.PolicyOverview,
          Clarity.Content.Ash.SecurityOverview,
          Clarity.Content.Ash.RelationshipOverview,
          Clarity.Content.Ash.StateMachineDiagram,
          Clarity.Content.Reactor.FlowDiagram,
          Clarity.Content.Phoenix.RouterRoutes,
          Clarity.Content.Advisory,
          Clarity.Content.Dependency
        ],
        clarity_status_providers: [
          Clarity.Status.SupplyChain
        ],
        clarity_reports: [
          Clarity.Report.Ontology,
          Clarity.Report.SupplyChain,
          Clarity.Report.SecurityPosture
        ],
        default_perspective_lens: "architect"
      ]
    ]
  end

  defp deps do
    [
      {:usage_rules, "~> 1.2", only: [:dev]},
      {:ash, "~> 3.6", optional: true},
      {:spark, "~> 2.3", optional: true},
      {:reactor, "~> 1.0", optional: true},
      {:ash_state_machine, "~> 0.2.13", optional: true},
      {:phoenix, "~> 1.8"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_view, "~> 1.0"},
      {:req, "~> 0.5"},
      {:hex_core, "~> 0.11"},
      {:mdex, "~> 0.14"},
      {:lumis, "~> 0.10"},
      # Lumis ships no grammars; each language is its own package. These cover
      # nearly every code block in Elixir project and dependency docs. Elixir
      # needs `comment` too, as it injects that grammar into comments.
      {:lumis_wasm_elixir, "~> 0.26"},
      {:lumis_wasm_comment, "~> 0.26"},
      {:lumis_wasm_iex, "~> 0.26"},
      {:lumis_wasm_heex, "~> 0.26"},
      {:lumis_wasm_bash, "~> 0.26"},
      {:lumis_wasm_javascript, "~> 0.26"},
      {:lumis_wasm_json, "~> 0.26"},
      {:telemetry, "~> 1.3"},
      {:telemetry_registry, "~> 0.3"},
      {:igniter, "~> 0.6", optional: true},
      # UI
      {:esbuild, "~> 0.8", only: [:dev, :test], runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.4", only: [:dev, :test], runtime: Mix.env() == :dev},
      # Development
      {:phx_new, "~> 1.7", only: [:test]},
      {:ex_doc, "~> 0.40", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.5", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctest_formatter, "~> 0.4", only: [:dev, :test], runtime: false},
      {:picosat_elixir, "~> 0.2.3", only: [:dev, :test]},
      {:floki, ">= 0.30.0", only: [:test]},
      {:lazy_html, ">= 0.1.0", only: [:test]},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.18", only: [:dev, :test]},
      {:ex_check, "~> 0.15", only: [:dev, :test]},
      {:git_ops, "~> 2.4", only: [:dev, :test], runtime: false}
    ]
  end

  # Refresh the committed assets before packaging, but only where the frontend
  # toolchain is present. CI has no `node_modules` (and can't build), so it
  # packages the committed `app.js`/`app.css` as-is; a maintainer publishing
  # locally gets a fresh build instead of shipping stale assets.
  defp build_assets_for_publish(_args) do
    if File.dir?("assets/node_modules") do
      Mix.Task.run("assets.deploy")
    end
  end

  defp aliases do
    [
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default --sourcemap=linked"],
      # No `phx.digest`: `Clarity.Resources` inlines the built assets into the
      # page at compile time rather than serving them over HTTP, so digesting
      # would only add unused duplicate files to the package.
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify"],
      "hex.build": [&build_assets_for_publish/1, "hex.build"],
      "hex.publish": [&build_assets_for_publish/1, "hex.publish"],
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
      extras: [
        "documentation/how_to/integrate-from-a-library.md"
      ],
      groups_for_extras: [
        "How To": ~r'documentation/how_to'
      ],
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
          ~r/^Clarity\.Content(?!\.(Ash|Spark|Phoenix))/
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
