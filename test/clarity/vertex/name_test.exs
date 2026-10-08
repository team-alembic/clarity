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

  doctest Name

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

  describe inspect(&Name.display_all/2) do
    @spec modules([module()]) :: [ModuleVertex.t()]
    defp modules(names), do: Enum.map(names, &%ModuleVertex{module: &1})

    test "uses the short name when siblings' short names differ" do
      assert Name.display_all(modules([Demo.Accounts, Demo.Billing.Plan]), :short) ==
               ["Accounts", "Plan"]
    end

    test "adds the module before a short name that clashes, until it is unique" do
      siblings = modules([Demo.Billing.Domain, Demo.Org.Domain, Demo.Accounts])

      assert Name.display_all(siblings, :short) == ["Billing.Domain", "Org.Domain", "Accounts"]
    end

    test "keeps adding modules while the clash continues" do
      siblings = modules([A.Shared.Domain, B.Shared.Domain])

      assert Name.display_all(siblings, :short) == ["A.Shared.Domain", "B.Shared.Domain"]
    end

    test "a module that ends another keeps its full name" do
      siblings = modules([Shared.Domain, Other.Shared.Domain])

      assert Name.display_all(siblings, :short) == ["Shared.Domain", "Other.Shared.Domain"]
    end

    test "leaves vertices that aren't named after a module alone" do
      siblings = [
        %Application{app: :clarity, description: nil, version: "0.4.0"}
        | modules([Demo.Billing.Domain, Demo.Org.Domain])
      ]

      assert Name.display_all(siblings, :short) == ["clarity", "Billing.Domain", "Org.Domain"]
    end

    test "shows qualified names unchanged" do
      siblings = modules([Demo.Billing.Domain, Demo.Org.Domain])

      assert Name.display_all(siblings, :qualified) == ["Demo.Billing.Domain", "Demo.Org.Domain"]
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

  describe inspect(&Name.display_path/2) do
    @app %Application{app: :demo, description: "Demo", version: Version.parse!("0.1.0")}

    test "leaves out of each name what the path before it says, when short" do
      path = [@app, %Domain{domain: Demo.Accounts}, %Resource{resource: User}]

      assert Name.display_path(path, :short) == ["demo", "Accounts", "User"]
      assert Name.display_path(path, :qualified) == ["demo", "Demo.Accounts", "Demo.Accounts.User"]
    end

    test "keeps the full name of a module outside the path's application" do
      path = [@app, %ModuleVertex{module: Baz}]

      assert Name.display_path(path, :short) == ["demo", "Foo.Bar.Baz"]
    end
  end
end
