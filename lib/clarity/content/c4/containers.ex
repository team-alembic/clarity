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
      width: 180
      height: 220
      style.fill: "#08427b"
      style.font-color: "#ffffff"
      style.stroke: "#073b6f"
    }

    host: |md
      ## Host Phoenix App
      [Software System]

      Owns modules, domains, supervisors, routes.
    | {
      width: 240
      height: 130
      style.fill: "#999999"
      style.font-color: "#ffffff"
      style.stroke: "#6b6b6b"
    }

    editor: |md
      ## Code Editor
      [Software System]
    | {
      width: 200
      height: 90
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

        Tree, header, tabs, viz/d2/mermaid/flow renderers.
      | {
        width: 260
        height: 130
        style.fill: "#85bbf0"
        style.font-color: "#073b6f"
        style.stroke: "#1168bd"
      }

      page_live: |md
        ## PageLive
        [Container: Phoenix LiveView]

        URL → vertex/lens, breadcrumbs, themes, engines.
      | {
        width: 260
        height: 130
        style.fill: "#438dd5"
        style.font-color: "#ffffff"
        style.stroke: "#1168bd"
      }

      server: |md
        ## Clarity.Server
        [Container: GenServer]

        Work queue + in-progress tasks. Owns the active Graph.
      | {
        width: 260
        height: 130
        style.fill: "#438dd5"
        style.font-color: "#ffffff"
        style.stroke: "#1168bd"
      }

      workers: |md
        ## Worker Pool
        [Container: PartitionSupervisor]

        Pulls tasks, runs introspectors with a 30s timeout.
      | {
        width: 260
        height: 130
        style.fill: "#438dd5"
        style.font-color: "#ffffff"
        style.stroke: "#1168bd"
      }

      pubsub: |md
        ## PubSub Registry
        [Container: Elixir Registry]

        :work_started / :work_progress / :work_completed.
      | {
        width: 260
        height: 130
        style.fill: "#438dd5"
        style.font-color: "#ffffff"
        style.stroke: "#1168bd"
      }

      graph: |md
        ## Graph
        [Container: :digraph + ETS]

        Main / tree / provenance digraphs; vertex + index ETS tables.
      | {
        shape: cylinder
        width: 260
        height: 140
        style.fill: "#438dd5"
        style.font-color: "#ffffff"
        style.stroke: "#1168bd"
      }

      cache: |md
        ## Cache
        [Container: GenServer + file]

        Snapshots the graph; hands ETS tables to Server on boot.
      | {
        shape: cylinder
        width: 260
        height: 140
        style.fill: "#438dd5"
        style.font-color: "#ffffff"
        style.stroke: "#1168bd"
      }

      reloader: |md
        ## Code-reload Listener
        [Container: Phoenix.CodeReloader]

        Triggers incremental introspection on recompile.
      | {
        width: 260
        height: 130
        style.fill: "#438dd5"
        style.font-color: "#ffffff"
        style.stroke: "#1168bd"
      }

      page_live -> server: "Reads graph + queue [call]"
      page_live -> server: "Triggers introspection [cast]"
      page_live -> ui: "Pushes diff updates [WebSocket]"
      server -> pubsub: "Publishes work events"
      pubsub -> page_live: "Notifies progress"
      server -> workers: "Hands tasks out [call :pull_task]"
      workers -> server: "Acks / nacks / requeues [cast]"
      server -> graph: "Reads / mutates"
      cache -> graph: "Loads on boot"
      cache -> server: "Hands graph over [:ets.give_away/3]"
      reloader -> server: "Triggers incremental introspection"
    }

    dev -> clarity.ui: "Browses code [HTTPS / WebSocket]"
    clarity.workers -> host: "Reflects on modules, domains [BEAM]"
    clarity.reloader -> host: "Listens for recompiles"
    clarity.page_live -> editor: "Opens file:line:col [System.cmd/3]"
    host -> clarity.page_live: "Mounts at /clarity [Phoenix Router]"

    key: |md
      ### Key
      - **Dashed boundary** — system in scope
      - Filled **mid-blue** rectangle — container (application)
      - Filled **mid-blue** cylinder — container that is a data store
      - **Person** shape — human actor
      - Filled **grey** rectangle — external system
      - Arrow labels: verb + [mechanism]
    | {
      near: bottom-right
      shape: text
      style.font-size: 12
    }
    """
  end
end
