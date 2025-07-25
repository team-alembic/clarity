defmodule AshAtlas.Introspector do
  @moduledoc """
  Defines the behaviour and orchestration logic for introspectors.

  Atlas introspects `ash` applications using an underlying `:digraph` structure,
  allowing visualization and exploration of resources, domains, actions, types,
  and more.

  This module defines the `AshAtlas.Introspector` behaviour and the default
  pipeline for built-in and user-defined introspectors. Each introspector
  receives a digraph and may add or modify vertices and edges. After all
  `introspect/1` calls, each introspector can optionally perform post-processing
  via `post_introspect/1`.

  ## Custom Introspectors

  You can define your own introspectors by implementing this behaviour and adding
  your module to the `:introspectors` config under the `:ash_atlas` application.

  ```elixir
  config :ash_atlas, :introspectors, [
    MyApp.MyCustomIntrospector
  ]
  ```

  ## Example

  Here's a simplified example of a custom introspector implementation:

  ```elixir
  defmodule MyApp.MyCustomIntrospector do
    @behaviour AshAtlas.Introspector

    alias AshAtlas.Vertex

    @impl AshAtlas.Introspector
    def introspect(graph) do
      for %Vertex.Resource{resource: resource} = resource_vertex <- :digraph.vertices(graph) do
        # Create a custom vertex for the resource
        custom_vertex = %Vertex.Custom{resource: resource}
        custom_vertex_id = Vertex.unique_id(custom_vertex)
        :digraph.add_vertex(graph, custom_vertex, custom_vertex_id)

        # Add an edge from the resource to the custom vertex
        :digraph.add_edge(graph, resource_vertex, custom_vertex, :custom)
      end

      graph
    end

    @impl AshAtlas.Introspector
    def post_introspect(graph) do
      del_vertices =
        for %Vertex.Custom{} = custom_vertex <- :digraph.vertices(graph),
            # No outgoing edges
            0 == :digraph.out_degree(graph, custom_vertex),
            # Only one incoming edge (resource)
            1 == :digraph.in_degree(graph, custom_vertex),
            do: custom_vertex

      :digraph.del_vertices(graph, del_vertices)

      graph
    end
  end
  ```
  """

  @typedoc """
  A module implementing the AshAtlas.Introspector behaviour.
  """
  @type t() :: module()

  @doc """
  Builds and processes the introspection graph using the built-in and configured
  introspectors.

  Each introspector first modifies the graph using `c:introspect/1`, and then may
  apply further changes with `c:post_introspect/1`.

  Returns the final `:digraph.t()` structure.
  """
  @callback introspect(graph :: :digraph.t()) :: :digraph.t()

  @doc """
  Called after the main graph resolution phase.

  Allows introspectors to further refine or clean up the graph. For example, it
  can remove vertices that are not used anywhere and therefore are not relevant
  for visualization.

  Must return the modified `:digraph.t()` structure.
  """
  @callback post_introspect(graph :: :digraph.t()) :: :digraph.t()

  @optional_callbacks [
    post_introspect: 1
  ]

  @doc """
  Builds and processes the introspection graph using the built-in and configured
  introspectors.

  Returns the final `:digraph.t()` structure.
  """
  @spec introspect(graph :: :digraph.t(), introspectors :: [t()]) :: :digraph.t()
  def introspect(graph, introspectors \\ introspectors()) do
    graph = Enum.reduce(introspectors, graph, & &1.introspect(&2))

    introspectors
    |> Enum.reverse()
    |> Enum.filter(&function_exported?(&1, :post_introspect, 1))
    |> Enum.reduce(graph, & &1.post_introspect(&2))
  end

  @native_introspectors [
    AshAtlas.Introspector.Root,
    AshAtlas.Introspector.Application,
    AshAtlas.Introspector.Domain,
    AshAtlas.Introspector.DataLayer,
    AshAtlas.Introspector.Action,
    AshAtlas.Introspector.Field,
    AshAtlas.Introspector.Type,
    AshAtlas.Introspector.Diagram
  ]

  @doc """
  Returns the list of introspectors, including both built-in and user-defined
  ones.
  """
  @spec introspectors() :: [t()]
  def introspectors,
    do: @native_introspectors ++ Application.get_env(:ash_atlas, :introspectors, [])
end
