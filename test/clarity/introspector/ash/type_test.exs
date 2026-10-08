defmodule Clarity.Introspector.Ash.TypeTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Introspector.Ash.Type, as: TypeIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Type
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  describe inspect(&TypeIntrospector.introspect_vertex/2) do
    test "creates type edges for attribute vertices" do
      graph = Clarity.Graph.new()

      ash_app_vertex = %Vertex.Application{app: :ash, description: "Ash", version: "1.0.0"}
      Clarity.Graph.add_vertex(graph, ash_app_vertex, %Root{})

      attribute_vertex = %Vertex.Ash.Attribute{
        attribute: %{name: :first_name, type: Ash.Type.String},
        resource: User
      }

      # Create a type vertex first so it exists in the graph
      type_vertex = %Type{type: Ash.Type.String}
      Clarity.Graph.add_vertex(graph, type_vertex, ash_app_vertex)

      assert {:ok,
              [
                {:edge, ^attribute_vertex, ^type_vertex, :type}
              ]} = TypeIntrospector.introspect_vertex(attribute_vertex, graph)
    end

    test "creates type edges for aggregates whose type Ash infers" do
      graph = Clarity.Graph.new()

      ash_app_vertex = %Vertex.Application{app: :ash, description: "Ash", version: "1.0.0"}
      Clarity.Graph.add_vertex(graph, ash_app_vertex, %Root{})

      # A count leaves the aggregate's type unset; Ash infers Integer.
      aggregate = Enum.find(Info.aggregates(User), &(&1.name == :admin_count))
      aggregate_vertex = %Vertex.Ash.Aggregate{aggregate: aggregate, resource: User}

      type_vertex = %Type{type: Ash.Type.Integer}
      Clarity.Graph.add_vertex(graph, type_vertex, ash_app_vertex)

      assert {:ok, [{:edge, ^aggregate_vertex, ^type_vertex, :type}]} =
               TypeIntrospector.introspect_vertex(aggregate_vertex, graph)
    end
  end
end
