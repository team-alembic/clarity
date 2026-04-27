defmodule Clarity.Content.C4.SystemContext do
  @moduledoc """
  C4 Level 1 — System Context diagram for Clarity.

  Renders Clarity as the system in scope, surrounded by the people and
  external software systems it interacts with. Follows the C4 model
  (https://c4model.com) conventions — `c4-person` shape for actors,
  filled blue rectangle for the in-scope system, grey for external
  systems, labelled relationships, and an explicit diagram key.

  Only applies to the `:clarity` Application vertex itself, since the
  diagram describes Clarity's own architecture rather than that of any
  application Clarity happens to be inspecting.
  """

  @behaviour Clarity.Content

  alias Clarity.Vertex.Application

  @impl Clarity.Content
  def name, do: "C4 — System Context"

  @impl Clarity.Content
  def description,
    do: "Level 1 of the C4 model — Clarity in relation to its users and external systems"

  @impl Clarity.Content
  def sort_priority, do: -97

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
      # System Context — Clarity
    | {near: top-center; shape: text}

    direction: down

    dev: |md
      ## Elixir Developer
      [Person]
    | {
      shape: c4-person
      width: 200
      height: 240
      style.fill: "#08427b"
      style.font-color: "#ffffff"
      style.stroke: "#073b6f"
    }

    clarity: |md
      ## Clarity
      [Software System]

      Interactive introspection & visualisation for Elixir projects. Mounted into the host app at /clarity.
    | {
      width: 320
      height: 150
      style.fill: "#1168bd"
      style.font-color: "#ffffff"
      style.stroke: "#0b4884"
    }

    host: |md
      ## Host Phoenix App
      [Software System]

      The user's Phoenix / Ash app. Owns the modules, domains, supervisors and routes.
    | {
      width: 260
      height: 140
      style.fill: "#999999"
      style.font-color: "#ffffff"
      style.stroke: "#6b6b6b"
    }

    editor: |md
      ## Code Editor
      [Software System]

      Local editor — VS Code, Cursor, Neovim, Emacs, …
    | {
      width: 260
      height: 140
      style.fill: "#999999"
      style.font-color: "#ffffff"
      style.stroke: "#6b6b6b"
    }

    forge: |md
      ## Source Forge
      [Software System]

      GitHub / GitLab / Codeberg / Bitbucket.
    | {
      width: 260
      height: 140
      style.fill: "#999999"
      style.font-color: "#ffffff"
      style.stroke: "#6b6b6b"
    }

    dev -> clarity: "Explores code [HTTPS / WebSocket]"
    clarity -> host: "Introspects modules, domains [BEAM reflection]"
    clarity -> editor: "Opens file:line:col [System.cmd/3]"
    clarity -> forge: "Deep links to source [HTTPS]"
    host -> clarity: "Mounts at /clarity [Phoenix Router]"

    key: |md
      ### Key

      - Filled **blue** rectangle — system in scope
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
