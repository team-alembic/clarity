# Atlas

**TODO: Add description**

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

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/atlas>.

