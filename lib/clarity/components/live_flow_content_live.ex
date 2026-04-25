defmodule Clarity.LiveFlowContentLive do
  @moduledoc """
  Generic wrapper LiveView for content providers returning `{:live_flow, ...}`.

  Builds the initial `LiveFlow.State` from the provider's flow definition and
  delegates rendering to `LiveFlow.Components.Flow`. The Flow LiveComponent
  already handles all standard `lf:*` events internally (drag, viewport,
  selection, edits) — it has `phx-target={@myself}` on the hook element, so
  hook-emitted events route to it directly.

  Custom node renderers in a content provider can emit
  `phx-click="lf:navigate_to_vertex"` with a `phx-value-vertex-id` attribute to
  navigate to another vertex page; that event bubbles to this wrapper LiveView
  (no `phx-target`) and is translated to `push_navigate/2`.

  Mounted via `live_render/3` from `render_content.html.heex` whenever a
  content provider's `render_static/2` returns `{:live_flow, fun}`.
  """

  use Phoenix.LiveView

  alias Clarity.Perspective.Lensmaker
  alias LiveFlow.State

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    %{
      "provider" => provider,
      "vertex" => vertex,
      "lens_id" => lens_id,
      "theme" => theme,
      "engine" => engine,
      "prefix" => prefix,
      "zoom_level" => zoom_level,
      "shown_vertex_types" => shown_vertex_types,
      "available_vertex_types" => available_vertex_types
    } = session

    # Phoenix LiveView's signed session can't carry the full Lens struct because
    # it contains anonymous functions (filter, content_sorter, ...). Look up the
    # lens by id instead.
    {:ok, lens} = Lensmaker.get_lens_by_id(lens_id)

    content_props = %{
      theme: theme,
      engine: engine,
      zoom_subgraph: nil,
      zoom_level: zoom_level,
      shown_vertex_types: shown_vertex_types,
      available_vertex_types: available_vertex_types
    }

    {:live_flow, fun} = provider.render_static(vertex, lens)
    flow_def = fun.(content_props)

    nodes = Map.fetch!(flow_def, :nodes)
    edges = Map.fetch!(flow_def, :edges)
    opts = Map.get(flow_def, :opts, %{})
    node_types = Map.get(flow_def, :node_types, %{})

    flow = State.new(nodes: nodes, edges: edges)

    socket =
      assign(socket,
        flow: flow,
        flow_opts: opts,
        node_types: node_types,
        provider: provider,
        vertex: vertex,
        lens: lens,
        theme: theme,
        prefix: prefix
      )

    {:ok, socket, layout: false}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="content h-full">
      <.live_component
        module={LiveFlow.Components.Flow}
        id="live-flow-canvas"
        flow={@flow}
        opts={@flow_opts}
        node_types={@node_types}
      />
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("lf:navigate_to_vertex", %{"vertex-id" => vertex_id}, socket) do
    %{prefix: prefix, lens: lens} = socket.assigns

    # Use redirect/2 (hard HTTP redirect) rather than push_navigate/2: the
    # nested-LiveView->push_navigate flow re-mounts PageLive over websocket and
    # PageLive's mount uses push_patch when connected, which raises during
    # mount. A hard redirect side-steps the issue and is fine for navigating
    # between vertex pages.
    {:noreply, redirect(socket, to: Path.join([prefix, lens.id, vertex_id]))}
  end

  # Any `lf:*` events that escape Flow's `phx-target={@myself}` (e.g. hooks
  # firing before the target is rebound) bubble here. Drop them silently —
  # losing one frame of viewport state is harmless.
  def handle_event("lf:" <> _rest, _params, socket), do: {:noreply, socket}

  @doc """
  Renders a flow definition as a human-readable Elixir term for the raw-content
  drawer. Function references in `:node_types` are preserved as `#Function<...>`
  via `inspect/2`.
  """
  @spec inspect_flow_def(map()) :: String.t()
  def inspect_flow_def(flow_def) when is_map(flow_def) do
    inspect(flow_def, pretty: true, limit: :infinity, printable_limit: :infinity)
  end
end
