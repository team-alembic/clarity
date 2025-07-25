# AshAtlas

**TODO: Add description**

## Installation

### Igniter

```bash
mix igniter.install ash_atlas@github:team-alembic/atlas
```

### Manual

The package can be installed by adding `ash_atlas` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:ash_atlas, github: "team-alembic/atlas", branch: "main"}
  ]
end
```

Router:
```elixir
import AshAtlas.Router
ash_atlas("/atlas")
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ash_atlas>.

