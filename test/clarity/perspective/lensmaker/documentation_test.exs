defmodule Clarity.Perspective.Lensmaker.DocumentationTest do
  use ExUnit.Case, async: true

  alias Clarity.Content
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker.Documentation
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Phoenix.Router
  alias Phoenix.LiveView.Rendered

  describe "make_lens/0" do
    test "shows only domain overviews and module documentation" do
      assert %Lens{id: "documentation", name: "Documentation", contents: contents} =
               Documentation.make_lens()

      assert contents == [Content.Ash.DomainOverview, Content.Moduledoc]
    end

    test "keeps the tree to what carries documentation" do
      lens = Documentation.make_lens()

      available = [
        Vertex.Application,
        Domain,
        Resource,
        Vertex.Ash.Attribute,
        Vertex.Module,
        Router
      ]

      assert lens.show_vertex_types.(available) == [
               Vertex.Application,
               Domain,
               Resource,
               Vertex.Module,
               Router
             ]
    end

    test "has an icon" do
      assert %Rendered{} = Documentation.make_lens().icon.()
    end
  end
end
