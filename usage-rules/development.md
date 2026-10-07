# Development Guide

Instructions for developing and testing Clarity locally.

## Running the Dev Server

The demo in `demo/` is a separate Phoenix application that depends on Clarity
the way any host app would, with `{:clarity, path: ".."}` in its `mix.exs`.
Fetch its dependencies once:

```bash
cd demo && mix deps.get
```

Then start it from the repository root:

```bash
mix dev
```

or from inside `demo/` with `mix phx.server`. This runs the demo at
http://localhost:4000 with:
- Live reload for both the demo's and Clarity's code
- Watchers that rebuild Clarity's assets (esbuild, tailwind)
- Sample Ash domains, resources and Phoenix routes to introspect

To use a different port:

```bash
PORT=4001 mix dev
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
