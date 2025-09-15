defmodule Clarity.Vertex.ContentTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Content

  describe "Clarity.Vertex protocol implementation for Content" do
    setup do
      vertex = %Content{
        id: "test_content",
        name: "Test Content",
        content: {:markdown, "# Test"}
      }

      {:ok, vertex: vertex}
    end

    test "unique_id/1 returns correct unique identifier", %{vertex: vertex} do
      assert Vertex.unique_id(vertex) == "content:test_content"
    end

    test "graph_id/1 returns correct graph identifier", %{vertex: vertex} do
      assert Vertex.graph_id(vertex) == "test_content"
    end

    test "graph_group/1 returns empty list", %{vertex: vertex} do
      assert Vertex.graph_group(vertex) == []
    end

    test "type_label/1 returns correct type label", %{vertex: vertex} do
      assert Vertex.type_label(vertex) == "Clarity.Vertex.Content"
    end

    test "render_name/1 returns correct display name", %{vertex: vertex} do
      assert Vertex.render_name(vertex) == "Test Content"
    end

    test "dot_shape/1 returns correct shape", %{vertex: vertex} do
      assert Vertex.dot_shape(vertex) == "nil"
    end

    test "markdown_overview/1 returns empty list", %{vertex: vertex} do
      assert Vertex.markdown_overview(vertex) == []
    end
  end

  describe "Content struct with different content types" do
    test "creates struct with markdown content" do
      vertex = %Content{
        id: "markdown_test",
        name: "Markdown Test",
        content: {:markdown, "# Hello World"}
      }

      assert vertex.id == "markdown_test"
      assert vertex.name == "Markdown Test"
      assert vertex.content == {:markdown, "# Hello World"}
    end

    test "creates struct with mermaid content" do
      vertex = %Content{
        id: "mermaid_test",
        name: "Mermaid Test",
        content: {:mermaid, "graph TD; A-->B;"}
      }

      assert vertex.content == {:mermaid, "graph TD; A-->B;"}
    end

    test "creates struct with viz content" do
      vertex = %Content{
        id: "viz_test",
        name: "Viz Test",
        content: {:viz, "digraph { A -> B }"}
      }

      assert vertex.content == {:viz, "digraph { A -> B }"}
    end

    test "creates struct with live_view content" do
      vertex = %Content{
        id: "live_view_test",
        name: "LiveView Test",
        content: {:live_view, {MyLiveView, %{}}}
      }

      assert vertex.content == {:live_view, {MyLiveView, %{}}}
    end

    test "creates struct with function content" do
      content_fn = fn -> "dynamic content" end

      vertex = %Content{
        id: "function_test",
        name: "Function Test",
        content: {:markdown, content_fn}
      }

      assert match?({:markdown, fun} when is_function(fun), vertex.content)
    end
  end

  describe "Content struct validation" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Content, %{})
      end
    end

    test "requires all keys to be present" do
      assert_raise ArgumentError, fn ->
        struct!(Content, %{id: "test"})
      end
    end
  end
end
