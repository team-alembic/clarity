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

  @typedoc """
  An introspection entry returned by introspectors.

  - `{:vertex, vertex}` - Adds a new vertex to the graph
  - `{:edge, from_vertex, to_vertex, label}` - Adds an edge between vertices
  - `{:purge, vertex}` - Removes a vertex and all vertices caused by it

  > #### Warning - Internal API {: .warning}
  >
  > The `{:purge, vertex}` entry type is for internal use by Clarity's
  > Application and Module introspectors only. Custom introspectors
  > must not emit purge entries.
  """
  @type entry() ::
          {:vertex, Vertex.t()}
          | {:edge, Vertex.t(), Vertex.t(), term()}
          | {:purge, Vertex.t()}

  @typedoc """
  What `c:introspect_vertex/2` returns: entries to add to the graph, or
  `{:error, :unmet_dependencies}` (with the modules waited for, if it can say)
  when something it needs isn't in the graph yet, or another error.
  """
  @type result() ::
          {:ok, [entry()]}
          | {:error, :unmet_dependencies | {:unmet_dependencies, [module()]} | term()}

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
  yet), it should return `{:error, :unmet_dependencies}`. The task is retried
  once the graph has more in it, allowing other introspectors to run first and
  potentially satisfy the dependencies.

  Better, it can return `{:error, {:unmet_dependencies, modules}}`, naming the
  modules whose introspection would satisfy them. The project's own
  applications are introspected before their dependencies, which follow in the
  background, so a module from a dependency (an Ash type, a Spark DSL, a
  behaviour) may be a while coming unless something asks for it: naming it
  has it introspected straight away.

  If an unexpected error occurs, return `{:error, reason}`. The worker will
  log the error and acknowledge the task to prevent infinite retries.
  """
  @callback introspect_vertex(vertex :: Vertex.t(), graph :: Clarity.Graph.t()) :: result()

  @doc """
  Whether what the introspector finds can change while the code doesn't,
  because it reads data fetched at runtime (`Clarity.Introspector.Advisory`
  reads the advisory database).

  A graph loaded from the cache is kept for vertices whose code is unchanged,
  so their introspectors don't run again; one that returns `true` here does,
  on every vertex of its types. It can also be run again whenever its data
  changes, with `Clarity.introspect/2` and `{:introspector, module}`.
  Optional; `false` when not implemented.
  """
  @callback reads_runtime_data?() :: boolean()

  @optional_callbacks reads_runtime_data?: 0
end
