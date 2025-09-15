defmodule Mix.Tasks.Clarity.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  test "installs clarity" do
    phx_test_project()
    |> Igniter.compose_task("clarity.install", [])
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
end
