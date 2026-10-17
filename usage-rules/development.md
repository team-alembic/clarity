# Development Guide

Instructions for developing and testing Clarity locally.

## Running the Dev Server

The demo in `demo/` is a separate Phoenix application that depends on Clarity
the way any host app would, through a path dependency on this checkout, and
also uses `ash_diagram`'s diagram tabs. Fetch its dependencies once:

```bash
cd demo && mix deps.get
```

Then start it from the repository root:

```bash
bin/dev
```

or from inside `demo/` with `mix phx.server`. This runs the demo at
http://localhost:4000/clarity (`/` redirects there) with:
- Live reload for both the demo's and Clarity's code
- Watchers that rebuild Clarity's assets (esbuild, tailwind)
- Sample Ash domains, resources and Phoenix routes to introspect

To use a different port:

```bash
PORT=4001 bin/dev
```

## Project Structure

- `demo/` - Demo application (its own Mix project)
  - `demo/lib/demo/` - Demo Ash domains and resources
  - `demo/lib/demo_web/` - Demo Phoenix endpoint and router
  - `demo/config/` - Demo configuration, including the dev server
- `config/config.exs` - Clarity's asset and test configuration

Clarity's test build also compiles `demo/lib`, so the tests run against the
demo's domains, resources and router.

## Building Assets

Assets are automatically watched in dev mode. For manual builds:

```bash
# Install asset tools if needed
mix assets.setup

# Build assets
mix assets.build

# Build for production
mix assets.deploy
```

esbuild splits the JS: `app.js` is the entry every page loads, and anything
a hook imports with `import()` becomes a chunk in `chunks/`, loaded the first
time it's needed. Mermaid (and each kind of Mermaid diagram) and Graphviz load
this way, so a page without a diagram never fetches them. Import any large
library the same way rather than at the top of a hook. `Clarity.Assets` serves
the entry, the chunks and the host's Phoenix and LiveView JS at
`prefix/assets/`, cached until Clarity changes; `mix assets.deploy` also
gzips them.

## Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/path/to/test.exs

# Run with coverage
mix test --cover
```

## Code Quality

```bash
# Run all checks
mix check

# Individual tools
mix format
mix credo
mix dialyzer
```
