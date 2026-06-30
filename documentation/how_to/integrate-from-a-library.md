# Integrating a Library with Clarity

This guide is for **library authors** who want their library's
vertex types, content providers, introspectors, or lensmakers to
appear in Clarity automatically whenever a consumer has both
Clarity and the library installed.

It describes the "wrap what you have" pattern: a library ships a
thin adapter guarded by `Code.ensure_loaded?/1`, registers it in
its own `application/0` environment, and Clarity auto-discovers
it on startup. The host project doesn't need to add any
`config :clarity_content_providers` line — or anything at all —
beyond the two `deps` entries.

> **Writing a provider in your own application?** The
> application-author path is simpler: register providers directly
> via `config :my_app, :clarity_content_providers, [...]` in your
> `config/config.exs`. Library-side integration, described below,
> is the right move for a reusable library but not for a
> Phoenix/Ash application.

## Why library-side integration?

Clarity content is owned most naturally by the library whose
concepts it visualises. Co-locating the adapter with the DSL it
describes gives four properties that a central bridge library
cannot match:

- **Versioning moves together.** A DSL change and its diagram
  change live in the same commit, so the UI never drifts from the
  DSL.
- **No central bottleneck.** There's no single library that has to
  accept a pull request for every new extension in the ecosystem.
- **Discoverability.** Consumers of the library find the Clarity
  integration in the library's own README, CHANGELOG, and HexDocs.
- **Scoping is automatic.** If the library is not used in the host
  project, no module is compiled; if Clarity is not installed,
  the Clarity adapter is skipped at compile time.

**Reserve central packages such as
[`ash_diagram`](https://hex.pm/packages/ash_diagram) for genuinely
cross-cutting visualisations** — entity-relationship diagrams
spanning a whole domain, C4-style architecture overviews, anything
that is not owned by a single extension. Extension-specific
visualisations belong in the extension itself.

## The three-part contract

A library integrates with Clarity by doing three things in concert.
Each is independently harmless if Clarity is absent.

### 1. Guard the adapter module with `Code.ensure_loaded?/1`

Wrap the entire module definition in a `with`-clause so the module
is only compiled when the Clarity behaviour it depends on is loaded:

```elixir
with {:module, _} <- Code.ensure_loaded(Clarity.Content) do
  defmodule MyLibrary.Clarity.MyDiagram do
    @behaviour Clarity.Content

    alias Clarity.Vertex

    @impl Clarity.Content
    def name, do: "My Diagram"

    @impl Clarity.Content
    def description, do: "A short description of what this renders."

    @impl Clarity.Content
    def applies?(%Vertex.Ash.Resource{resource: resource}, _lens),
      do: relevant?(resource)

    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Vertex.Ash.Resource{resource: resource}, _lens) do
      {:mermaid, fn _props -> MyLibrary.Charts.diagram(resource) end}
    end

    defp relevant?(resource) do
      # your predicate — e.g. "does this resource use my extension?"
      MyLibrary.Extension in Spark.extensions(resource)
    end
  end
end
```

The same pattern applies for the other extension points: guard on
`Clarity.Introspector` for introspectors, on `Clarity.Vertex` for
vertex types, and on `Clarity.Perspective.Lensmaker` for lensmakers.

### 2. Register the module via `application/0` in `mix.exs`

Expose the adapter through your library's environment. Clarity
walks every loaded application's environment at startup and
aggregates registered providers — no host-side configuration
required.

```elixir
# mix.exs
def application do
  [
    extra_applications: [:logger],
    env: [
      clarity_content_providers: [
        MyLibrary.Clarity.MyDiagram
      ]
    ]
  ]
end
```

The same environment keys exist for the other extension points:

| Provider type     | Environment key                   |
| ----------------- | --------------------------------- |
| Content providers | `:clarity_content_providers`      |
| Introspectors     | `:clarity_introspectors`          |
| Lensmakers        | `:clarity_perspective_lensmakers` |
| Status providers  | `:clarity_status_providers`       |

### 3. Declare Clarity as an optional dependency

In `defp deps/0`:

```elixir
defp deps do
  [
    # ...your usual deps...
    {:clarity, "~> 0.4", optional: true}
  ]
end
```

`optional: true` gives you three properties at once:

- Consumers who install your library without Clarity get no
  Clarity code — the guarded module never compiles.
- Consumers who install both get the integration automatically.
- `mix deps.get` in your own library resolves Clarity so you can
  develop and test the adapter locally.

## Recommended module naming

Use `YourLibrary.Clarity.*` as the namespace for Clarity-facing
modules. For example:

- `MyLibrary.Clarity.SomeDiagram` — a content provider
- `MyLibrary.Clarity.Introspector` — a custom introspector
- `MyLibrary.Clarity.Vertex.SomeThing` — a custom vertex type

Avoid the older `ClarityContent.*` naming used in some early
integrations: it is redundant with the library namespace (the
Clarity context is already implicit) and leaves no room for
introspectors, vertex types, or lensmakers in the same tree.

## Listing under "Third-Party Libraries"

Once your library ships Clarity integration, open a pull request
against the Clarity README adding it to the Third-Party Libraries
section. A one-liner is enough:

```markdown
- **[my_library](https://hex.pm/packages/my_library)** – Short
  description of what the Clarity integration visualises.
```

## Worked examples

- [`ash_diagram`](https://hex.pm/packages/ash_diagram) ships five
  Clarity content providers (`ErDiagram`, `ClassDiagram`,
  `ArchitectureDiagram`, `PolicyDiagram`, `PolicySimulation`), each
  guarded with `Code.ensure_loaded?/1` and registered via
  `application/0`. Read its `mix.exs` and
  `lib/ash_diagram/clarity_content/*.ex` for a reference
  implementation of the pattern described above.
- [`ash_state_machine`](https://hex.pm/packages/ash_state_machine)
  ships a single state-diagram content provider at
  `AshStateMachine.Clarity.StateMachineDiagram`, demonstrating the
  minimal-surface-area version of the pattern.
