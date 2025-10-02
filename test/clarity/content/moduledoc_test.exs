defmodule Clarity.Content.ModuledocTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Moduledoc
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Module
  alias Clarity.Vertex.Root
  alias Demo.Accounts.Domain, as: TestDomain
  alias Demo.Accounts.User

  describe inspect(&Moduledoc.name/0) do
    test "returns module documentation name" do
      assert Moduledoc.name() == "Module Documentation"
    end
  end

  describe inspect(&Moduledoc.description/0) do
    test "returns module documentation description" do
      assert Moduledoc.description() == "Documentation for this module"
    end
  end

  describe inspect(&Moduledoc.applies?/2) do
    test "returns true for Module vertex with moduledoc" do
      vertex = %Module{module: Enum, version: :unknown}
      lens = nil

      assert Moduledoc.applies?(vertex, lens) == true
    end

    test "returns true for Domain vertex with moduledoc" do
      vertex = %Domain{domain: TestDomain}
      lens = nil

      assert Moduledoc.applies?(vertex, lens) == true
    end

    test "returns false for Resource vertex without moduledoc" do
      vertex = %Resource{resource: User}
      lens = nil

      assert Moduledoc.applies?(vertex, lens) == false
    end

    test "returns false for vertices without modules" do
      vertex = %Root{}
      lens = nil

      assert Moduledoc.applies?(vertex, lens) == false
    end

    test "returns false for modules without moduledoc" do
      defmodule TestModuleWithoutDoc do
        @moduledoc false
      end

      vertex = %Module{module: TestModuleWithoutDoc, version: :unknown}
      lens = nil

      assert Moduledoc.applies?(vertex, lens) == false
    end
  end

  describe inspect(&Moduledoc.render_static/2) do
    test "returns markdown tuple for Module vertex" do
      vertex = %Module{module: Enum, version: :unknown}
      lens = nil

      assert {:markdown, markdown_fn} = Moduledoc.render_static(vertex, lens)
      assert is_function(markdown_fn, 1)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = markdown_fn.(props)
      assert is_binary(markdown)
      assert String.length(markdown) > 0
    end

    test "returns markdown tuple for Domain vertex" do
      vertex = %Domain{domain: TestDomain}
      lens = nil

      assert {:markdown, markdown_fn} = Moduledoc.render_static(vertex, lens)
      assert is_function(markdown_fn, 1)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = markdown_fn.(props)
      assert is_binary(markdown)
      assert markdown =~ "Accounts domain"
    end

    test "returns markdown tuple for Module vertex with documentation" do
      vertex = %Module{module: String, version: :unknown}
      lens = nil

      assert {:markdown, markdown_fn} = Moduledoc.render_static(vertex, lens)
      assert is_function(markdown_fn, 1)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = markdown_fn.(props)
      assert is_binary(markdown)
      assert String.length(markdown) > 0
    end
  end
end
