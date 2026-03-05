# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## Project Overview

Clarity is an interactive introspection and visualisation tool for Elixir projects. It automatically discovers and visualises applications, domains, resources, modules, and their relationships through a navigable graph interface. Currently in alpha (v0.4.0).

## Development Commands

```bash
# Start development server (runs esbuild/tailwind watchers, starts endpoint at :4000)
mix dev

# Run full check suite (formatter, credo, dialyzer, tests, etc.)
mix ex_check --no-retry

# Run tests
mix test
mix test path/to/test.exs           # Single file
mix test path/to/test.exs:42        # Single test at line

# Format code (uses Styler plugin)
mix format

# Build assets
mix assets.build

# Update usage rules documentation
mix usage_rules.update
```

## Architecture

Clarity is built around four main extension points, all registered via application configuration:

### 1. Vertex Types (`lib/clarity/vertex/`)
Define node types in the graph. All vertices implement the `Clarity.Vertex` protocol with `id/1`, `type_label/1`, and `name/1`. Organised by framework:
- `ash/` - Ash resources, domains, actions, attributes, policies, etc.
- `spark/` - Spark DSL entities, sections, extensions
- `phoenix/` - Endpoints, routers

### 2. Introspectors (`lib/clarity/introspector/`)
Analyse code to discover vertices and edges. Implement the `Clarity.Introspector` behaviour with `source_vertex_types/0` and `introspect_vertex/2`. Return `{:ok, entries}` where entries are `{:vertex, v}` or `{:edge, from, to, label}`. Return `{:error, :unmet_dependencies}` to retry later when dependencies are missing.

### 3. Content Providers (`lib/clarity/content/`)
Display information about vertices in the UI. Implement `Clarity.Content` behaviour with `name/0`, `applies?/2`, and render methods. Support markdown, mermaid diagrams, graphviz, and LiveView components.

### 4. Lensmakers (`lib/clarity/perspective/lensmaker/`)
Create filtered views of the graph for different audiences (architect, security, debug). Implement `Clarity.Perspective.Lensmaker` behaviour with `make_lens/0` and `update_lens/1`.

### 5. Graph Backends (`lib/clarity/graph/backend/`)
Pluggable storage backends for the graph. Implement `Clarity.Graph.Backend` behaviour. The default `Digraph` backend uses Erlang's `:digraph` and ETS tables. External backends (Neo4j, ArcadeDB) use Cypher over HTTP.
- `digraph.ex` - Default in-process backend using `:digraph`/ETS
- `neo4j.ex` - Neo4j backend via HTTP transaction API
- `arcade_db.ex` - ArcadeDB backend via HTTP command API
- `cypher.ex` - Shared Cypher query builder used by Neo4j and ArcadeDB

### Core Modules

- `Clarity.Server` - GenServer orchestrating introspection via PartitionSupervisor workers
- `Clarity.Graph` - Graph facade delegating to a configured backend. Owns policy guards (ownership, writability)
- `Clarity.Graph.Backend` - Behaviour defining the graph storage API (~25 callbacks)
- `Clarity.Graph.Filter` - Tuple-based query syntax for filtering vertices
- `Clarity.Router` - Phoenix router macros (`import Clarity.Router`, then `clarity "/clarity"`)

## Key Patterns

### Vertex ID Generation
Use `Clarity.Vertex.Util.id/2` for consistent, globally unique IDs:
```elixir
Util.id(MyVertex, ["parent", "child"])  # => "Elixir.MyVertex:parent:child"
```

### Module Detection
Always use `Code.ensure_loaded/1` before `function_exported?/3`.

### Graph Query Syntax
```elixir
{:==, :vertex_type, Clarity.Vertex.Module}
{:and, query1, query2}
{:in, :vertex_type, [Type1, Type2]}
```

## Configuration

Key config options in `config/config.exs`:
```elixir
config :clarity, :ash_domains, [Demo.Accounts.Domain]
config :clarity, :auto_start?, false
config :clarity, :introspector_applications, [:my_app]
config :clarity, :default_perspective_lens, "architect"
config :clarity, :editor, "code --goto __FILE__:__LINE__:__COLUMN__"

# Graph backend (default is Digraph, no config needed)
config :clarity, :graph_backend, Clarity.Graph.Backend.Neo4j
config :clarity, Clarity.Graph.Backend.Neo4j,
  url: "http://localhost:7474",
  auth: {:basic, "neo4j", "password"},
  database: "clarity"
```

Register extensions per-application:
```elixir
config :my_app, :clarity_introspectors, [MyApp.CustomIntrospector]
config :my_app, :clarity_content_providers, [MyApp.CustomContent]
config :my_app, :clarity_perspective_lensmakers, [MyApp.CustomLensmaker]
```

## Code Style

- Formatter plugins: Styler, DoctestFormatter, Phoenix.LiveView.HTMLFormatter
- Use `@impl ModuleName` (not `@impl true`)
- Include `@spec` for all public functions except callbacks
- Router macros don't need parens: `clarity "/clarity"`

## Testing

Tests mirror the lib structure. Integration tests for graph operations, component tests for LiveView. The `dev/` directory contains a demo app (Demo, DemoWeb) used during development.

## Usage Rules Documentation

Detailed extension guides are in `usage-rules/`:
- `vertex-types.md` - Creating vertex types
- `introspectors.md` - Creating introspectors
- `content-providers.md` - Creating content providers
- `lensmakers.md` - Creating lenses
- `graph-backends.md` - Configuring and creating graph backends
