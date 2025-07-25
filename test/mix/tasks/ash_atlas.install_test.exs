defmodule Mix.Tasks.AshAtlas.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  test "installs atlas" do
    phx_test_project()
    |> Igniter.compose_task("ash_atlas.install", [])
    |> assert_has_patch(".formatter.exs", """
       |[
     - |  import_deps: [:ecto, :ecto_sql, :phoenix],
     + |  import_deps: [:ash_atlas, :ecto, :ecto_sql, :phoenix],
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
     + |    import AshAtlas.Router
     + |
     + |    scope "/atlas" do
     + |      pipe_through :browser
     + |
     + |      ash_atlas("/")
     + |    end
     + |  end
       |end
       |
    """)
    |> apply_igniter!()
    |> Igniter.compose_task("ash_atlas.install", [])
    |> assert_unchanged()
  end

  test "warns if there's no phoenix router found" do
    test_project()
    |> Igniter.compose_task("ash_atlas.install", [])
    |> assert_has_warning("""
    No Phoenix router found or selected. Please ensure that Phoenix is set up
    and then run this installer again with

        mix ash_atlas.install
    """)
  end
end
