defmodule Atlas.Introspector do
  @moduledoc """
  Defines the behaviour and orchestration logic for introspectors.

  Atlas introspects `ash` applications using an underlying `:digraph` structure,
  allowing visualization and exploration of resources, domains, actions, types,
  and more.

  This module defines the `Atlas.Introspector` behaviour and the default
  pipeline for built-in and user-defined introspectors. Each introspector
  receives a digraph and may add or modify vertices and edges. After all
  `introspect/1` calls, each introspector can optionally perform post-processing
  via `post_introspect/1`.

  ## Custom Introspectors

  You can define your own introspectors by implementing this behaviour and adding
  your module to the `:introspectors` config under the `:atlas` application.

  ```elixir
  config :atlas, :introspectors, [
    MyApp.MyCustomIntrospector
  ]
  ```

  ## Example

  Here's a simplified example of a custom introspector implementation:

  ```elixir
  defmodule MyApp.MyCustomIntrospector do
    @behaviour Atlas.Introspector

    alias Atlas.Vertex

    @impl Atlas.Introspector
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

    @impl Atlas.Introspector
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

  alias Atlas.Vertex

  @typedoc """
  A module implementing the Atlas.Introspector behaviour.
  """
  @type t() :: module()

  @doc """
  Builds and processes the introspection graph using the built-in and configured
  introspectors.

  Each introspector first modifies the graph using `c:introspect/1`, and then may
  apply further changes with `c:post_introspect/1`.

  Returns the final `:digraph.graph()` structure.
  """
  @callback introspect(graph :: :digraph.graph()) :: :digraph.graph()

  @doc """
  Called after the main graph resolution phase.

  Allows introspectors to further refine or clean up the graph. For example, it
  can remove vertices that are not used anywhere and therefore are not relevant
  for visualization.

  Must return the modified `:digraph.graph()` structure.
  """
  @callback post_introspect(graph :: :digraph.graph()) :: :digraph.graph()

  @optional_callbacks [
    post_introspect: 1
  ]

  @doc """
  Builds and processes the introspection graph using the built-in and configured
  introspectors.

  Returns the final `:digraph.graph()` structure.
  """
  @spec introspect(graph :: :digraph.graph(), introspectors :: [t()]) :: :digraph.graph()
  def introspect(graph, introspectors \\ introspectors()) do
    graph = Enum.reduce(introspectors, graph, & &1.introspect(&2))

    introspectors
    |> Enum.reverse()
    |> Enum.filter(&function_exported?(&1, :post_introspect, 1))
    |> Enum.reduce(graph, & &1.post_introspect(&2))
  end

  @native_introspectors [
    Atlas.Introspector.Root,
    Atlas.Introspector.Application,
    Atlas.Introspector.Domain,
    Atlas.Introspector.DataLayer,
    Atlas.Introspector.Action,
    Atlas.Introspector.Field,
    Atlas.Introspector.Type,
    Atlas.Introspector.Diagram
  ]

  @doc """
  Returns the list of introspectors, including both built-in and user-defined
  ones.
  """
  @spec introspectors() :: [t()]
  def introspectors, do: @native_introspectors ++ Application.get_env(:atlas, :introspectors, [])

  @doc """
  Attaches the moduledoc content of a module to the introspection graph.
  """
  @spec attach_moduledoc_content(
          module :: module(),
          graph :: :digraph.graph(),
          vertex :: :digraph.vertex()
        ) :: :ok
  def attach_moduledoc_content(module, graph, vertex) do
    with {:docs_v1, _annotation, _beam_language, "text/markdown", %{"en" => moduledoc}, _metadata,
          _docs} <-
           Code.fetch_docs(module) do
      content_vertex = %Vertex.Content{
        id: inspect(module) <> "_moduledoc",
        name: "Module Documentation",
        content: {:markdown, moduledoc}
      }

      :digraph.add_vertex(graph, content_vertex)
      :digraph.add_edge(graph, vertex, content_vertex, :content)
    end

    :ok
  end
end
