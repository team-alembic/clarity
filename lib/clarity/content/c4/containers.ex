defmodule Clarity.Content.C4.Containers do
  @moduledoc """
  C4 Level 2 — Container diagram for Clarity.

  Zooms inside the Clarity system to show the major containers
  (applications and data stores) and how they communicate. Follows the
  C4 model (https://c4model.com) conventions — the system in scope is
  the dashed boundary, containers inside are filled lighter blue
  rectangles annotated with technology, external systems are grey, and
  every relationship carries a verb + protocol label.

  Only applies to the `:clarity` Application vertex.
  """

  @behaviour Clarity.Content

  alias Clarity.Vertex.Application

  @impl Clarity.Content
  def name, do: "C4 — Containers"

  @impl Clarity.Content
  def description,
    do: "Level 2 of the C4 model — applications and data stores inside Clarity"

  @impl Clarity.Content
  def sort_priority, do: -96

  @impl Clarity.Content
  def applies?(%Application{app: :clarity}, _lens), do: true
  def applies?(_vertex, _lens), do: false

  @impl Clarity.Content
  def render_static(%Application{}, _lens) do
    {:d2, fn _props -> diagram() end}
  end

  @spec diagram() :: iodata()
  defp diagram do
    """
    title: |md
      # Containers — Clarity
    | {near: top-center; shape: text}

    direction: down

    dev: |md
      ## Elixir Developer
      [Person]
    | {
      shape: c4-person
      style.fill: "#08427b"
      style.font-color: "#ffffff"
      style.stroke: "#073b6f"
    }

    host: |md
      ## Host Phoenix Application
      [Software System]

      Provides the HTTP endpoint that mounts Clarity, plus the modules /
      Ash domains / supervisors that Clarity introspects.
    | {
      style.fill: "#999999"
      style.font-color: "#ffffff"
      style.stroke: "#6b6b6b"
    }

    editor: |md
      ## Code Editor
      [Software System]
    | {
      style.fill: "#999999"
      style.font-color: "#ffffff"
      style.stroke: "#6b6b6b"
    }

    clarity: {
      label: |md
        # Clarity
        [Software System]
      |
      style: {
        fill: "#ffffff"
        stroke: "#0b4884"
        stroke-width: 2
        stroke-dash: 5
        font-color: "#0b4884"
      }

      ui: |md
        ## Browser SPA
        [Container: HEEx + LiveView client]

        Renders the navigation tree, header (lens / engine / name-style /
        theme switchers), tabbed content area and tooltips. Hosts the
        graph hooks that drive **Graphviz (viz-js)**, **Mermaid**, **D2**
        and **React Flow** renderings.
      | {
        style.fill: "#85bbf0"
        style.font-color: "#073b6f"
        style.stroke: "#1168bd"
      }

      page_live: |md
        ## PageLive
        [Container: Phoenix LiveView]

        Stateful root LiveView. Owns the URL → `{lens, vertex}` mapping,
        breadcrumbs, theme, engine, name-style and zoom level. Streams
        navigation tree + tooltips to the browser; subscribes to the
        Clarity Server's PubSub.
      | {
        style.fill: "#438dd5"
        style.font-color: "#ffffff"
        style.stroke: "#1168bd"
      }

      server: |md
        ## Clarity.Server
        [Container: GenServer]

        Orchestrator. Holds the work queue, in-progress task map, the
        active Graph, the active Introspector list, and the cache
        handle. Exposes `pull_task` / `ack_task` / `nack_task` /
        `requeue_task` / `introspect` / `get` over GenServer.
      | {
        style.fill: "#438dd5"
        style.font-color: "#ffffff"
        style.stroke: "#1168bd"
      }

      workers: |md
        ## Worker Pool
        [Container: PartitionSupervisor of GenServers]

        One Worker per scheduler partition. Pulls a Task, runs the
        introspector under a 30-second `Task.async`, then acks / nacks
        / requeues the result. Trapping exits keeps the supervisor
        healthy across introspector crashes.
      | {
        style.fill: "#438dd5"
        style.font-color: "#ffffff"
        style.stroke: "#1168bd"
      }

      pubsub: |md
        ## PubSub Registry
        [Container: Elixir Registry]

        Pub/sub fan-out for `:work_started`, `:work_progress`,
        `:work_completed` and per-vertex events. The Server publishes;
        StatusLive, PageLive and content components subscribe.
      | {
        style.fill: "#438dd5"
        style.font-color: "#ffffff"
        style.stroke: "#1168bd"
      }

      graph: |md
        ## Graph
        [Container: `:digraph` + ETS]

        In-memory model. Three digraphs (main, tree, provenance) plus
        ETS tables for vertices, indexes and the update counter. Ownership
        is transferred between processes via `:ets.give_away/3` so the
        cache can hand the loaded graph to the Server.
      | {
        shape: cylinder
        style.fill: "#438dd5"
        style.font-color: "#ffffff"
        style.stroke: "#1168bd"
      }

      cache: |md
        ## Cache
        [Container: GenServer + on-disk file]

        Persists the discovered graph between runs. On boot, hands the
        loaded graph to the Server; on shutdown / introspection
        completion, snapshots state to disk.
      | {
        shape: cylinder
        style.fill: "#438dd5"
        style.font-color: "#ffffff"
        style.stroke: "#1168bd"
      }

      reloader: |md
        ## Code-reload Listener
        [Container: `Phoenix.CodeReloader` listener]

        Watches recompilation events from the host app and triggers
        incremental introspection so the live graph stays in sync with
        the developer's edits.
      | {
        style.fill: "#438dd5"
        style.font-color: "#ffffff"
        style.stroke: "#1168bd"
      }

      page_live -> server: "Reads graph + queue\n[GenServer.call]"
      page_live -> server: "Triggers introspection\n[GenServer.cast]"
      page_live -> ui: "Pushes diff updates\n[LiveView WebSocket]"
      server -> pubsub: "Publishes work events"
      pubsub -> page_live: "Notifies of progress"
      server -> workers: "Hands tasks out\n[GenServer.call :pull_task]"
      workers -> server: "Acks / nacks / requeues\n[GenServer.cast]"
      server -> graph: "Reads / mutates"
      cache -> graph: "Loads on boot;\nsnapshots on idle"
      cache -> server: "Hands graph over\n[`:ets.give_away/3`]"
      reloader -> server: "Triggers incremental\nintrospection"
    }

    dev -> clarity.ui: "Browses code\n[HTTPS / WebSocket]"
    clarity.workers -> host: "Reflects on modules,\ndomains, supervisors\n[BEAM]"
    clarity.reloader -> host: "Listens for recompiles\n[Phoenix.CodeReloader]"
    clarity.page_live -> editor: "Opens file:line:col\n[`System.cmd/3`]"
    host -> clarity.page_live: "Mounts at `/clarity`\n[Phoenix Router]"

    key: |md
      ### Key

      - **Dashed boundary** — the system in scope.
      - Filled **mid-blue** rectangle — a container (application).
      - Filled **mid-blue** cylinder — a container that is a data store.
      - Filled **dark blue** person — a human actor.
      - Filled **grey** rectangle — external system.
      - Arrow labels: verb describing the interaction + `[mechanism]`.
    | {
      near: bottom-right
      shape: text
      style.font-size: 11
    }
    """
  end
end
