<!-- ex_doc_ignore_start -->
# Atlas
<!-- ex_doc_ignore_end -->

⚠️ **Alpha Notice**: Atlas is currently in an **alpha state**. APIs and features
may change rapidly, and things may break. Feedback and contributions are very
welcome!


Atlas is an interactive introspection and visualization tool for Elixir projects.  
It automatically discovers and visualizes applications, domains, resources,
modules, and their relationships, giving you a navigable graph interface
enriched with diagrams, tooltips, and documentation.

![Screenshot Placeholder](docs/screenshot.png)

## Features

- 📊 **Graph navigation** – explore your application structure visually.
- 🗂 **Extensible introspection** – support for Ash domains/resources, Phoenix
  endpoints, Ecto repos, and more.
- 🖼 **Mermaid & Graphviz diagrams** – ER diagrams, class diagrams, and policy
  diagrams where available.
- 📝 **Markdown rendering** – show documentation from moduledocs and resource
  definitions.
- 🔎 **Interactive tooltips** – quick overviews of nodes and edges.
- ⚡ **LiveView-powered** – fully dynamic, real-time updates in the browser.
- 🔌 **Custom extensions** – add your own introspectors to visualize
  domain-specific concepts.

## Installation

### Igniter

```bash
mix igniter.install atlas@github:team-alembic/atlas
```

### Manual

The package can be installed by adding `atlas` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:atlas, github: "team-alembic/atlas", branch: "main"}
  ]
end
```

Endpoint (just below the existing `Plug.Static`):
```elixir
plug Plug.Static,
  at: "/atlas",
  from: :atlas,
  gzip: true,
  only: Atlas.Web.static_paths()
```

Router:
```elixir
import Atlas.Router
atlas("/atlas")
```

<!-- ex_doc_ignore_start -->
Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm).The docs can be found at
<https://hexdocs.pm/atlas>.
<!-- ex_doc_ignore_end -->

## License

Copyright 2025 Alembic Pty Ltd

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
