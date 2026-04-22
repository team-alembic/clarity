# Integrating a Library with Clarity

This file is a condensed rules summary for AI coding assistants.
Human readers: see the full guide at
[`documentation/how_to/integrate-from-a-library.md`](../documentation/how_to/integrate-from-a-library.md).

## When to apply

You are writing or modifying a **library** (not an end-user
application) and you want the library to ship Clarity content —
content providers, introspectors, custom vertex types, or
lensmakers — that appears automatically whenever a consumer also
installs Clarity.

For end-user applications, use `config :my_app, :clarity_*` in
`config/config.exs` instead — see
[`content-providers.md`](content-providers.md),
[`introspectors.md`](introspectors.md),
[`vertex-types.md`](vertex-types.md),
[`lensmakers.md`](lensmakers.md).

## Rules

1. **Guard every Clarity adapter module** with a top-level
   `Code.ensure_loaded?/1` check so the module is only compiled
   when Clarity is present:

   ```elixir
   with {:module, _} <- Code.ensure_loaded(Clarity.Content) do
     defmodule MyLibrary.Clarity.SomeProvider do
       @behaviour Clarity.Content
       # ...
     end
   end
   ```

   Guard target by extension point:

   | Extension point   | Guard on                            |
   | ----------------- | ----------------------------------- |
   | Content provider  | `Clarity.Content`                   |
   | Introspector      | `Clarity.Introspector`              |
   | Vertex type       | `Clarity.Vertex`                    |
   | Lensmaker         | `Clarity.Perspective.Lensmaker`     |

2. **Register via `application/0` in `mix.exs`**, never via
   `config/*.exs` in a library:

   ```elixir
   def application do
     [
       extra_applications: [:logger],
       env: [
         clarity_content_providers: [MyLibrary.Clarity.SomeProvider]
       ]
     ]
   end
   ```

   Environment keys:

   - `:clarity_content_providers`
   - `:clarity_introspectors`
   - `:clarity_perspective_lensmakers`

3. **Declare Clarity as an optional dep**:

   ```elixir
   {:clarity, "~> 0.4", optional: true}
   ```

4. **Naming**: use `YourLibrary.Clarity.*` as the namespace. Avoid
   `YourLibrary.ClarityContent.*` — it is redundant with the
   library namespace and leaves no room for introspectors, vertex
   types, or lensmakers in the same tree.

5. **Scope**: only ship adapters for concepts your library owns.
   Cross-cutting visualisations (entity-relationship diagrams,
   C4-style architecture) belong in
   [`ash_diagram`](https://hex.pm/packages/ash_diagram) or an
   equivalent central package, not in extension libraries.
