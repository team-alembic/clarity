# Development Guide

Instructions for developing and testing Clarity locally.

## Running the Dev Server

First, ensure asset tools are installed at the correct versions:

```bash
mix esbuild.install
mix tailwind.install
```

Then start the development server with the demo application:

```bash
mix dev
```

This runs the demo Phoenix application at http://localhost:4000 with:
- Live reload for code changes
- Asset watchers (esbuild, tailwind)
- The Demo application with sample Ash domains

To use a different port:

```bash
PORT=4001 mix dev
```

## Project Structure

The development environment uses:

- `dev/` - Demo application code
  - `dev/demo/` - Demo Ash domains and resources
  - `dev/demo_web/` - Demo Phoenix endpoint and router
- `dev.exs` - Development server startup script
- `config/config.exs` - Development configuration

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
