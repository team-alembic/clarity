# Graph Backends

Graph backends control how Clarity stores and queries its graph
data. The default backend uses Erlang's `:digraph` and ETS tables
for fast in-process storage. External backends (Neo4j, ArcadeDB)
store the graph in an external database, enabling persistence and
native graph queries.

## Available Backends

### Digraph (Default)

No configuration needed. Uses `:digraph` and ETS tables. Best for
development and most production use cases.

```elixir
# Explicit (not required, this is the default)
config :clarity, :graph_backend, Clarity.Graph.Backend.Digraph
```

### Neo4j

Stores the graph in a Neo4j database via its HTTP transaction API.

```elixir
config :clarity, :graph_backend, Clarity.Graph.Backend.Neo4j
config :clarity, Clarity.Graph.Backend.Neo4j,
  url: "http://localhost:7474",
  auth: {:basic, "neo4j", "password"},
  database: "clarity"
```

Requires a running Neo4j instance. Uses native Cypher
`shortestPath()` for path queries and variable-length path
matching for reachability.

### ArcadeDB

Stores the graph in an ArcadeDB database via its HTTP command API.

```elixir
config :clarity, :graph_backend, Clarity.Graph.Backend.ArcadeDB
config :clarity, Clarity.Graph.Backend.ArcadeDB,
  url: "http://localhost:2480",
  auth: {:basic, "root", "password"},
  database: "clarity"
```

Requires a running ArcadeDB instance. Uses Cypher queries via
ArcadeDB's multi-model query engine.

## How Backends Work

All backends implement the `Clarity.Graph.Backend` behaviour,
which defines ~25 callbacks covering:

- **Lifecycle**: `new/1`, `delete/2`, `clear/1`, `handover/3`
- **Writes**: `add_vertex/5`, `add_edge/4`, `purge/2`
- **Reads**: `get_vertex/2`, `vertex_count/1`, `get_update_count/1`
- **Edges**: `out_neighbors/2`, `in_neighbors/2`, `out_edges/2`,
  `in_edges/2`, `edges/1`, `edge/2`
- **Degree**: `in_degree/2`, `in_degree/3`, `out_degree/2`,
  `out_degree/3`
- **Query**: `vertices/2`, `vertex_ids/2`,
  `available_vertex_types/1`
- **Navigation**: `breadcrumbs/2`, `get_short_path/3`,
  `navigation_children/2`
- **Traversal**: `vertices_within_steps/4`, `reachable_from/2`
- **Subgraph**: `create_subgraph/2`
- **Persistence**: `persist/2`, `load/2`

`Clarity.Graph` delegates all operations to the configured backend
while keeping policy guards (ownership checks, subgraph
write-protection) in the facade.

## External Backend Details

### No Extra Dependencies

Both Neo4j and ArcadeDB backends use HTTP APIs via `Req`, which
is already available in Phoenix projects. No Bolt driver or other
dependencies needed.

### Write Batching

External backends buffer `add_vertex` and `add_edge` calls
internally and flush them as a single transaction when the batch
size is reached or when a read operation requires fresh data.

### Subgraph as Virtual View

When `Graph.filter/2` creates a subgraph, external backends store
the set of included vertex IDs and add WHERE clauses to all
subsequent queries rather than copying data.

### Shared Cypher Layer

Both Neo4j and ArcadeDB use Cypher queries. The shared
`Clarity.Graph.Backend.Cypher` module handles:

- Query DSL to Cypher WHERE clause translation
- Vertex struct serialization/deserialization
- Common Cypher statement builders

### Vertex Serialization

Vertex structs are stored as ETF-encoded binary data in a `data`
property. Queryable fields (`:app`, `:module`, `:name`,
`:description`) are promoted to top-level properties prefixed with
`prop_` so they can be filtered with native Cypher:

```
v.type = 'Elixir.Clarity.Vertex.Module'
v.prop_app = 'my_app'
```

## Creating a Custom Backend

Implement the `Clarity.Graph.Backend` behaviour:

```elixir
defmodule MyApp.CustomBackend do
  @behaviour Clarity.Graph.Backend

  @impl Clarity.Graph.Backend
  def new(opts) do
    # Initialize and return state
  end

  @impl Clarity.Graph.Backend
  def add_vertex(state, vertex_id, vertex_type, vertex_struct,
                 caused_by_id) do
    # Store vertex and return updated state
  end

  # ... implement all callbacks
end
```

Configure it:

```elixir
config :clarity, :graph_backend, MyApp.CustomBackend
```

### Key Implementation Notes

- The `state` value returned from `new/1` is passed to all other
  callbacks. It can be any term (struct, map, pid, etc.)
- Write callbacks (`add_vertex`, `add_edge`, `clear`, `purge`)
  must return updated state
- `handover/3` transfers ownership to another process. For
  external backends this is typically a no-op
- `create_subgraph/2` returns new state representing a filtered
  view. For in-process backends this creates actual subgraphs;
  for external backends it can store a filter set
- `persist/2` and `load/2` handle disk serialization. External
  backends may export/import from the database

### Testing

Test your backend against the existing graph test suite by
creating a graph with your backend:

```elixir
graph = Clarity.Graph.new(backend: MyApp.CustomBackend)
```

All operations in `Clarity.Graph` will delegate to your backend.
