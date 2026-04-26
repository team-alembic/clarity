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

      Application architect / developer exploring the structure of an
      Elixir / Phoenix / Ash code base — domains, resources, supervision
      trees, routers and the relationships between them.
    | {
      shape: c4-person
      style.fill: "#08427b"
      style.font-color: "#ffffff"
      style.stroke: "#073b6f"
    }

    clarity: |md
      ## Clarity
      [Software System]

      Interactive introspection and visualisation tool for Elixir
      projects. Shipped as a library (`mix.exs` dependency); mounted into
      the host Phoenix app under `/clarity` and serves a LiveView UI of
      the host's discovered architecture.
    | {
      style.fill: "#1168bd"
      style.font-color: "#ffffff"
      style.stroke: "#0b4884"
    }

    host: |md
      ## Host Phoenix Application
      [Software System]

      The Elixir application that lists `:clarity` as a dependency. Owns
      the modules, Ash domains/resources, Phoenix endpoint/router and
      OTP supervision tree that Clarity introspects.
    | {
      style.fill: "#999999"
      style.font-color: "#ffffff"
      style.stroke: "#6b6b6b"
    }

    editor: |md
      ## Code Editor
      [Software System]

      Local editor process — VS Code, Cursor, Neovim, Emacs, … Clarity
      shells out (or generates a deep link) so the developer can jump
      from a vertex to its source at the exact line and column.
    | {
      style.fill: "#999999"
      style.font-color: "#ffffff"
      style.stroke: "#6b6b6b"
    }

    forge: |md
      ## Source Forge
      [Software System]

      GitHub / GitLab / Codeberg / Bitbucket. Used in URL mode to deep
      link to a file/line on the project's `source_url` so the developer
      can open code in the browser instead of a local editor.
    | {
      style.fill: "#999999"
      style.font-color: "#ffffff"
      style.stroke: "#6b6b6b"
    }

    dev -> clarity: |md
      Explores code structure via the **Clarity UI**

      [HTTPS / WebSocket]
    |
    clarity -> host: |md
      Introspects modules, domains, supervisors, routers and configuration

      [BEAM reflection / `Code.fetch_docs/1`]
    |
    clarity -> editor: |md
      Opens files at `__FILE__:__LINE__:__COLUMN__`

      [`System.cmd/3`]
    |
    clarity -> forge: |md
      Deep-links to the source on the configured branch / tag

      [HTTPS]
    |
    host -> clarity: |md
      Mounts the LiveView UI at `/clarity`

      [Phoenix Router macro]
    |

    key: |md
      ### Key

      - Filled **blue** rectangle — the system in scope.
      - Filled **dark blue** person — a human actor.
      - Filled **grey** rectangle — an external system Clarity interacts with.
      - Each arrow is labelled with the verb describing the interaction
        and the protocol / mechanism in `[brackets]`.
    | {
      near: bottom-right
      shape: text
      style.font-size: 11
    }
    """
  end
end
