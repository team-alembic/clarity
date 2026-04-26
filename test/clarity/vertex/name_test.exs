defmodule Clarity.Vertex.NameTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Module, as: ModuleVertex
  alias Clarity.Vertex.Name
  alias Clarity.Vertex.Phoenix.Router
  alias Clarity.Vertex.Root
  alias Clarity.Vertex.Spark.Section
  alias Demo.Accounts.User
  alias Foo.Bar.Baz

  describe inspect(&Name.display/2) do
    test "returns Vertex.name/1 for :qualified" do
      vertex = %Resource{resource: User}
      assert Name.display(vertex, :qualified) == Vertex.name(vertex)
      assert Name.display(vertex, :qualified) == "Demo.Accounts.User"
    end

    test "returns short name for :short on a resource vertex" do
      vertex = %Resource{resource: User}
      assert Name.display(vertex, :short) == "User"
    end

    test "returns short name for :short on a domain vertex" do
      vertex = %Domain{domain: Demo.Accounts}
      assert Name.display(vertex, :short) == "Accounts"
    end

    test "returns short name for :short on a Phoenix Router vertex" do
      vertex = %Router{router: DemoWeb.Router}
      assert Name.display(vertex, :short) == "Router"
    end

    test "returns short name for :short on a Module vertex" do
      vertex = %ModuleVertex{module: Baz, version: :unknown, behaviour?: false}
      assert Name.display(vertex, :short) == "Baz"
    end

    test "falls through to Vertex.name/1 when the vertex has no module" do
      vertex = %Application{app: :clarity, description: nil, version: "0.4.0"}
      assert Name.display(vertex, :short) == Vertex.name(vertex)

      assert Name.display(%Root{}, :short) == "Root"

      assert Name.display(%Section{module: User, path: [:relationships]}, :short) ==
               "relationships"
    end

    test "an unknown style falls through to qualified" do
      vertex = %Resource{resource: User}
      assert Name.display(vertex, :something_else) == "Demo.Accounts.User"
    end
  end

  describe inspect(&Name.short_module_name/1) do
    test "returns the last segment for elixir modules" do
      assert Name.short_module_name(Baz) == "Baz"
      assert Name.short_module_name(User) == "User"
    end

    test "falls back to inspect/1 for unsplittable atoms" do
      assert Name.short_module_name(:not_a_module) == ":not_a_module"
    end
  end
end
