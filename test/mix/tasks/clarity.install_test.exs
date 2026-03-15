defmodule Mix.Tasks.Clarity.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  @moduletag :slow

  test "installs clarity" do
    phx_test_project()
    |> Igniter.compose_task("clarity.install", [])
    |> assert_has_patch("mix.exs", """
    ...|
       |      deps: deps(),
       |      compilers: [:phoenix_live_view] ++ Mix.compilers(),
     - |      listeners: [Phoenix.CodeReloader]
     + |      listeners: [Phoenix.CodeReloader, Clarity.CodeReloader]
       |    ]
       |  end
    ...|
    """)
    |> assert_has_patch(".formatter.exs", """
       |[
     - |  import_deps: [:ecto, :ecto_sql, :phoenix],
     + |  import_deps: [:clarity, :ecto, :ecto_sql, :phoenix],
       |  subdirectories: ["priv/*/migrations"],
       |  plugins: [Phoenix.LiveView.HTMLFormatter],
    ...|
    """)
    |> assert_has_patch("lib/test_web/router.ex", """
    ...|
       |    end
       |  end
     + |
     + |  if Application.compile_env(:test, :dev_routes) do
     + |    import Clarity.Router
     + |
     + |    scope "/clarity" do
     + |      pipe_through :browser
     + |
     + |      clarity("/")
     + |    end
     + |  end
       |end
       |
    """)
    |> apply_igniter!()
    |> Igniter.compose_task("clarity.install", [])
    |> assert_unchanged()
  end

  test "warns if there's no phoenix router found" do
    test_project()
    |> Igniter.compose_task("clarity.install", [])
    |> assert_has_warning("""
    No Phoenix router found or selected. Please ensure that Phoenix is set up
    and then run this installer again with

        mix clarity.install
    """)
  end

  test "gives manual instruction with programmatic listeners" do
    phx_test_project()
    |> Igniter.update_file("mix.exs", fn source ->
      Rewrite.Source.update(source, :content, """
      defmodule Test.MixProject do
        use Mix.Project

        def project do
          [
            app: :test,
            version: "0.1.0",
            elixir: "~> 1.15",
            elixirc_paths: elixirc_paths(Mix.env()),
            start_permanent: Mix.env() == :prod,
            aliases: aliases(),
            deps: deps(),
            compilers: [:phoenix_live_view] ++ Mix.compilers(),
            listeners: listeners()
          ]
        end

        # Don't add Phoenix's code reloader when running Dependabot checks.
        # See https://elixirforum.com/t/phoenix-1-8-0-rc-0-released/70256/108 for details
        defp listeners do
          dependabot? =
            Enum.any?(System.get_env(), fn {key, _value} -> String.starts_with?(key, "DEPENDABOT") end)

          if dependabot? do
            []
          else
            [Phoenix.CodeReloader]
          end
        end

        # Configuration for the OTP application.
        #
        # Type `mix help compile.app` for more information.
        def application do
          [
            mod: {Test.Application, []},
            extra_applications: [:logger, :runtime_tools]
          ]
        end

        def cli do
          [
            preferred_envs: [precommit: :test]
          ]
        end

        # Specifies which paths to compile per environment.
        defp elixirc_paths(:test), do: ["lib", "test/support"]
        defp elixirc_paths(_), do: ["lib"]

        # Specifies your project dependencies.
        #
        # Type `mix help deps` for examples and options.
        defp deps do
          [
            {:phoenix, "~> 1.8.1"},
            {:phoenix_ecto, "~> 4.5"},
            {:ecto_sql, "~> 3.13"},
            {:postgrex, ">= 0.0.0"},
            {:phoenix_html, "~> 4.1"},
            {:phoenix_live_reload, "~> 1.2", only: :dev},
            {:phoenix_live_view, "~> 1.1.0"},
            {:lazy_html, ">= 0.1.0", only: :test},
            {:phoenix_live_dashboard, "~> 0.8.3"},
            {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
            {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
            {:heroicons,
             github: "tailwindlabs/heroicons",
             tag: "v2.2.0",
             sparse: "optimized",
             app: false,
             compile: false,
             depth: 1},
            {:swoosh, "~> 1.16"},
            {:req, "~> 0.5"},
            {:telemetry_metrics, "~> 1.0"},
            {:telemetry_poller, "~> 1.0"},
            {:gettext, "~> 0.26"},
            {:jason, "~> 1.2"},
            {:dns_cluster, "~> 0.2.0"},
            {:bandit, "~> 1.5"}
          ]
        end

        # Aliases are shortcuts or tasks specific to the current project.
        # For example, to install project dependencies and perform other setup tasks, run:
        #
        #     $ mix setup
        #
        # See the documentation for `Mix` for more info on aliases.
        defp aliases do
          [
            setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
            "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
            "ecto.reset": ["ecto.drop", "ecto.setup"],
            test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
            "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
            "assets.build": ["compile", "tailwind test", "esbuild test"],
            "assets.deploy": [
              "tailwind test --minify",
              "esbuild test --minify",
              "phx.digest"
            ],
            precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
          ]
        end
      end
      """)
    end)
    |> apply_igniter!()
    |> Igniter.compose_task("clarity.install", [])
    |> assert_has_warning("""
    Structure of `mix.exs` / `project` / `listeners` is not a list, manual installation required:
    Add `Clarity.CodeReloader` to the list of listeners in your `mix.exs` project function.
    """)
  end
end
