defmodule Clarity.Introspector do
  @moduledoc """
  Defines the behaviour and orchestration logic for introspectors.

  Clarity introspects `ash` applications using an underlying `:digraph` structure,
  allowing visualization and exploration of resources, domains, actions, types,
  and more.

  This module defines the `Clarity.Introspector` behaviour and the default
  pipeline for built-in and user-defined introspectors. Each introspector
  processes vertices individually through the `c:introspect_vertex/2` callback.

  ## Custom Introspectors

  Introspector configuration is managed by `Clarity.Config`. See the documentation
  for `Clarity.Config` for detailed configuration options and examples.

  ## Example

  Here's a simplified example of a custom introspector implementation:

  ```elixir
  defmodule MyApp.MyCustomIntrospector do
    @behaviour Clarity.Introspector

    alias Clarity.Vertex

    @impl Clarity.Introspector
    def source_vertex_types, do: [Vertex.Module]

    @impl Clarity.Introspector
    def introspect_vertex(%Vertex.Module{module: module} = module_vertex, _graph) do
      # Create a custom vertex for the module
      custom_vertex = %Vertex.Custom{module: module}

      [
        {:vertex, custom_vertex},
        {:edge, module_vertex, custom_vertex, :custom}
      ]
    end

    def introspect_vertex(_vertex, _graph), do: []
  end
  ```
  """

  alias Clarity.Vertex

  @typedoc """
  A module implementing the Clarity.Introspector behaviour.
  """
  @type t() :: module()

  @type entry() :: {:vertex, Vertex.t()} | {:edge, Vertex.t(), Vertex.t(), term()}
  @type result() :: {:ok, [result()]} | {:error, :unmet_dependencies | term()}

  @doc """
  Returns the list of vertex types this introspector can process.

  This is used to filter which introspectors should be run for each vertex type,
  improving performance by avoiding unnecessary task creation.
  """
  @callback source_vertex_types() :: [module()]

  @doc """
  Performs introspection on a single vertex in the async system.

  This callback is called by workers for each vertex that needs to be processed.
  The introspector receives the vertex to process and a read-only view of the 
  current graph state for context.

  Returns `{:ok, results}` on success, where `results` is a list of
  `{:vertex, vertex}` and `{:edge, from_vertex, to_vertex, label}` tuples to add
  to the graph.

  If the introspector cannot run due to missing dependencies in the graph
  (such as an Ash resource referencing a domain that hasn't been introspected
  yet), it should return `:missing_dependencies`. The worker will re-queue
  the task to be retried later, allowing other introspectors to run first
  and potentially satisfy the dependencies.

  If an unexpected error occurs, return `{:error, reason}`. The worker will
  log the error and acknowledge the task to prevent infinite retries.
  """
  @callback introspect_vertex(vertex :: Vertex.t(), graph :: Clarity.Graph.t()) :: result()

  @doc """
  Creates moduledoc content vertex and edge for the specified module.

  This function fetches the module's documentation and creates both a content vertex
  containing the moduledoc and an edge from the provided vertex to that content.

  ## Parameters

  - `module` - The module whose moduledoc content to create
  - `vertex` - The vertex that should be connected to the moduledoc content

  ## Returns

  Returns a list containing either:
  - `[{:vertex, content_vertex}, {:edge, vertex, content_vertex, :content}]` if moduledoc exists
  - `[]` if no moduledoc content exists for the module

  ## Example

      # In an introspector:
      def introspect_vertex(%MyVertex{module: module} = my_vertex, _graph) do
        [
          {:vertex, my_vertex}
          | Clarity.Introspector.moduledoc_content(module, my_vertex)
        ]
      end
  """
  @spec moduledoc_content(module(), Vertex.t()) :: [entry()]
  def moduledoc_content(module, vertex) do
    case Code.fetch_docs(module) do
      {:docs_v1, _annotation, _beam_language, "text/markdown", %{"en" => moduledoc}, _metadata,
       _docs} ->
        content_vertex = %Vertex.Content{
          id: inspect(module) <> "_moduledoc",
          name: "Module Documentation",
          content: {:markdown, moduledoc}
        }

        [
          {:vertex, content_vertex},
          {:edge, vertex, content_vertex, :content}
        ]

      _ ->
        []
    end
  end
end
