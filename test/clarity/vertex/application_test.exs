defmodule Clarity.Vertex.ApplicationTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Application

  describe "Clarity.Vertex protocol implementation for Application" do
    setup do
      vertex = %Application{
        app: :test_app,
        description: "Test Application",
        version: %Version{major: 1, minor: 2, patch: 3}
      }

      {:ok, vertex: vertex}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.unique_id(vertex) == "application:test_app"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex} do
      assert Vertex.graph_id(vertex) == "test_app"
    end

    test "graph_group/1 returns empty list", %{vertex: vertex} do
      assert Vertex.graph_group(vertex) == []
    end

    test "type_label/1 returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Application"
    end

    test "render_name/1 returns correct display name", %{vertex: vertex} do
      assert Vertex.render_name(vertex) == "test_app"
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "house"
    end

    test "markdown_overview/1 returns formatted overview", %{vertex: vertex} do
      overview = Vertex.markdown_overview(vertex)
      overview_string = IO.iodata_to_binary(overview)

      assert overview_string =~ "`:test_app`"
      assert overview_string =~ "Test Application"
      assert overview_string =~ "Version: `1.2.3`"
    end
  end

  describe "from_app_tuple/1" do
    test "creates Application vertex from app tuple with version string" do
      app_tuple = {:test_app, ~c"Test Application", ~c"1.2.3"}

      vertex = Application.from_app_tuple(app_tuple)

      assert vertex.app == :test_app
      assert vertex.description == "Test Application"
      assert vertex.version == %Version{major: 1, minor: 2, patch: 3}
    end

    test "creates Application vertex from app tuple with invalid version" do
      app_tuple = {:test_app, ~c"Test Application", ~c"invalid-version"}

      vertex = Application.from_app_tuple(app_tuple)

      assert vertex.app == :test_app
      assert vertex.description == "Test Application"
      assert vertex.version == "invalid-version"
    end
  end

  describe "Application struct" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Application, %{})
      end
    end

    test "creates struct with required fields" do
      vertex = %Application{
        app: :my_app,
        description: "My App",
        version: "1.0.0"
      }

      assert vertex.app == :my_app
      assert vertex.description == "My App"
      assert vertex.version == "1.0.0"
    end
  end
end
