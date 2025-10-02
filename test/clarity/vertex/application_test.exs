defmodule Clarity.Vertex.ApplicationTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Application

  setup do
    vertex = %Application{
      app: :test_app,
      description: "Test Application",
      version: %Version{major: 1, minor: 2, patch: 3}
    }

    {:ok, vertex: vertex}
  end

  describe inspect(&Vertex.id/1) do
    test "returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.id(vertex) == "application:test-app"
    end
  end

  describe inspect(&Vertex.type_label/1) do
    test "returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Application"
    end
  end

  describe inspect(&Vertex.name/1) do
    test "returns correct display name", %{vertex: vertex} do
      assert Vertex.name(vertex) == "test_app"
    end
  end

  describe inspect(&Clarity.Vertex.GraphGroupProvider.graph_group/1) do
    test "returns empty list", %{vertex: vertex} do
      assert Vertex.GraphGroupProvider.graph_group(vertex) == []
    end
  end

  describe inspect(&Clarity.Vertex.GraphShapeProvider.shape/1) do
    test "returns correct shape", %{vertex: vertex} do
      assert Vertex.GraphShapeProvider.shape(vertex) == "house"
    end
  end

  describe inspect(&Clarity.Vertex.TooltipProvider.tooltip/1) do
    test "returns formatted overview", %{vertex: vertex} do
      overview = Vertex.TooltipProvider.tooltip(vertex)
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
end
