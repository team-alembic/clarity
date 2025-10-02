with {:module, Phoenix.Endpoint} <- Code.ensure_loaded(Phoenix.Endpoint) do
  defmodule Clarity.Content.Phoenix.RouterRoutesTest do
    use ExUnit.Case, async: true

    alias Clarity.Content.Phoenix.RouterRoutes
    alias Clarity.Vertex.Phoenix.Router
    alias Clarity.Vertex.Root

    describe inspect(&RouterRoutes.name/0) do
      test "returns router routes name" do
        assert RouterRoutes.name() == "Routes"
      end
    end

    describe inspect(&RouterRoutes.description/0) do
      test "returns router routes description" do
        assert RouterRoutes.description() == "All routes defined in this router"
      end
    end

    describe inspect(&RouterRoutes.applies?/2) do
      test "returns true for Router vertices" do
        vertex = %Router{router: DemoWeb.Router}
        lens = nil

        assert RouterRoutes.applies?(vertex, lens) == true
      end

      test "returns false for non-Router vertices" do
        vertex = %Root{}
        lens = nil

        assert RouterRoutes.applies?(vertex, lens) == false
      end
    end

    describe inspect(&RouterRoutes.render_static/2) do
      test "returns markdown tuple with function" do
        vertex = %Router{router: DemoWeb.Router}
        lens = nil

        assert {:markdown, markdown_fn} = RouterRoutes.render_static(vertex, lens)
        assert is_function(markdown_fn, 1)
      end

      test "generated markdown includes table headers" do
        vertex = %Router{router: DemoWeb.Router}
        {:markdown, markdown_fn} = RouterRoutes.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "| Name | Method | Path | Plug | Action |"
      end

      test "generated markdown includes routes" do
        vertex = %Router{router: DemoWeb.Router}
        {:markdown, markdown_fn} = RouterRoutes.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "GET"
        assert markdown =~ "/"
      end

      test "generated markdown includes helper names" do
        vertex = %Router{router: DemoWeb.Router}
        {:markdown, markdown_fn} = RouterRoutes.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "_path"
      end

      test "generated markdown includes plug modules" do
        vertex = %Router{router: DemoWeb.Router}
        {:markdown, markdown_fn} = RouterRoutes.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "Phoenix.LiveView.Plug"
      end
    end
  end
end
