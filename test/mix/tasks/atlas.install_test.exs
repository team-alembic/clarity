defmodule Mix.Tasks.Atlas.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  test "installs atlas" do
    phx_test_project()
    |> Igniter.compose_task("atlas.install", [])
    |> assert_has_patch(".formatter.exs", """
       |[
     - |  import_deps: [:ecto, :ecto_sql, :phoenix],
     + |  import_deps: [:atlas, :ecto, :ecto_sql, :phoenix],
       |  subdirectories: ["priv/*/migrations"],
       |  plugins: [Phoenix.LiveView.HTMLFormatter],
    ...|
    """)
    |> assert_has_patch("lib/test_web/endpoint.ex", """
    ...|
       |  )
       |
     + |  plug Plug.Static, at: "/atlas", from: :atlas, gzip: true, only: Atlas.Web.static_paths()
     + |
       |  # Code reloading can be explicitly enabled under the
       |  # :code_reloader configuration of your endpoint.
    ...|
    """)
    |> assert_has_patch("lib/test_web/router.ex", """
    ...|
       |    end
       |  end
     + |
     + |  if Application.compile_env(:test, :dev_routes) do
     + |    import Atlas.Router
     + |
     + |    scope "/atlas" do
     + |      pipe_through :browser
     + |
     + |      atlas("/")
     + |    end
     + |  end
       |end
       |
    """)
    |> apply_igniter!()
    |> Igniter.compose_task("atlas.install", [])
    |> assert_unchanged()
  end

  test "warns if the preinstalled Plug.Static is not found in the endpoint" do
    phx_test_project()
    |> Igniter.update_file("lib/test_web/endpoint.ex", fn source ->
      Rewrite.Source.update(source, :content, """
      defmodule TestWeb.Endpoint do
        use Phoenix.Endpoint, otp_app: :test

        plug(TestWeb.Router)
      end
      """)
    end)
    |> apply_igniter!()
    |> Igniter.compose_task("atlas.install", [])
    |> assert_has_warning("""
    The location of the `Plug.Static` plug in your endpoint could not be
    determined. Please ensure that the preinstalled `Plug.Static` plug
    is present in your endpoint or add the following code manually:

        plug Plug.Static,
          at: "/atlas",
          from: :atlas,
          gzip: true,
          only: Atlas.Web.static_paths()
    """)
  end

  test "warns if there's no phoenix router found" do
    test_project()
    |> Igniter.compose_task("atlas.install", [])
    |> assert_has_warning("""
    No Phoenix router found or selected. Please ensure that Phoenix is set up
    and then run this installer again with

        mix atlas.install
    """)
    |> assert_has_warning("""
    No Phoenix endpoint found or selected. Please ensure that Phoenix is set up
    and then run this installer again with

        mix atlas.install
    """)
  end
end
