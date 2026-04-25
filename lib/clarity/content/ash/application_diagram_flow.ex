with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.ApplicationDiagramFlow do
    @moduledoc """
    Live_flow variant of the Application Diagram.

    Renders all Ash resources in an OTP application as draggable, clickable
    `LiveFlow` nodes laid out in a domain-grouped grid (one row per domain).
    Mirrors the Graphviz (`Clarity.Content.Ash.ApplicationDiagram`) and D2
    (`Clarity.Content.Ash.ApplicationDiagramD2`) variants so designers can
    compare engines side by side.

    Click a resource node to navigate to its vertex page.
    """

    @behaviour Clarity.Content

    use Phoenix.Component

    alias Clarity.Vertex.Application
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Util
    alias LiveFlow.Node, as: FlowNode

    # Grid layout constants — tuned for ~200x80 nodes with breathing room.
    @x_step 220
    @y_step 130
    @x_origin 0
    @y_origin 0

    @impl Clarity.Content
    def name, do: "Application Diagram (Flow)"

    @impl Clarity.Content
    def description, do: "Interactive flow diagram of all Ash resources, grouped by domain"

    @impl Clarity.Content
    def sort_priority, do: -80

    @impl Clarity.Content
    def applies?(%Application{app: app}, _lens) do
      Ash.Info.domains(app) != []
    end

    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Application{app: app}, _lens) do
      {:live_flow, fn props -> build_flow(app, props) end}
    end

    @spec build_flow(atom(), map()) :: map()
    defp build_flow(app, %{theme: theme}) do
      indexed = app |> Ash.Info.domains_and_resources() |> Enum.with_index()

      nodes =
        Enum.flat_map(indexed, fn {{domain, resources}, domain_idx} ->
          resources
          |> Enum.with_index()
          |> Enum.map(fn {resource, col} ->
            build_node(resource, domain, domain_idx, col, theme)
          end)
        end)

      %{
        nodes: nodes,
        edges: [],
        opts: %{
          controls: true,
          background: :dots,
          fit_view_on_init: true,
          snap_to_grid: true,
          snap_grid: {20, 20},
          nodes_connectable: false
        },
        node_types: %{resource: &resource_node/1}
      }
    end

    @spec build_node(module(), module(), non_neg_integer(), non_neg_integer(), atom()) ::
            FlowNode.t()
    defp build_node(resource, domain, domain_idx, col, theme) do
      {fill, stroke, fg} = domain_colors(domain_idx, theme)

      FlowNode.new(
        node_id(resource),
        %{x: @x_origin + col * @x_step, y: @y_origin + domain_idx * @y_step},
        %{
          label: short_name(resource),
          domain: inspect(domain),
          resource: inspect(resource),
          vertex_id: Util.id(Resource, [resource]),
          fill: fill,
          stroke: stroke,
          fg: fg
        },
        type: :resource,
        connectable: false
      )
    end

    @spec node_id(module()) :: String.t()
    defp node_id(resource), do: "res:" <> inspect(resource)

    @spec short_name(module()) :: String.t()
    defp short_name(module), do: module |> Module.split() |> List.last()

    # Function component used as the `:resource` node renderer. Receives the
    # full assigns from `LiveFlow.Components.NodeWrapper` — we destructure
    # `@node` for styling and click handling.
    attr :node, FlowNode, required: true

    @spec resource_node(map()) :: Phoenix.LiveView.Rendered.t()
    def resource_node(assigns) do
      ~H"""
      <div
        class="rounded-md shadow border-2 cursor-pointer select-none px-3 py-2 min-w-[180px] text-center font-semibold"
        style={[
          "background-color: ",
          @node.data.fill,
          ";",
          "border-color: ",
          @node.data.stroke,
          ";",
          "color: ",
          @node.data.fg,
          ";"
        ]}
        phx-click="lf:navigate_to_vertex"
        phx-value-vertex-id={@node.data.vertex_id}
        title={@node.data.resource}
      >
        <div class="text-sm leading-tight">{@node.data.label}</div>
        <div class="text-[10px] opacity-70 mt-1 leading-none">{@node.data.domain}</div>
      </div>
      """
    end

    # ----- Domain colour palette (copied from Clarity.Content.Ash.ApplicationDiagram) -----

    @light_palette [
      {"#fef3c7", "#a16207", "#1f2937"},
      {"#dcfce7", "#15803d", "#1f2937"},
      {"#dbeafe", "#1d4ed8", "#1f2937"},
      {"#fce7f3", "#be185d", "#1f2937"},
      {"#ede9fe", "#6d28d9", "#1f2937"},
      {"#ffedd5", "#c2410c", "#1f2937"},
      {"#ffe4e6", "#be123c", "#1f2937"},
      {"#cffafe", "#0e7490", "#1f2937"}
    ]

    @dark_palette [
      {"#854d0e", "#fbbf24", "#fef3c7"},
      {"#166534", "#4ade80", "#dcfce7"},
      {"#1e40af", "#60a5fa", "#dbeafe"},
      {"#9d174d", "#f472b6", "#fce7f3"},
      {"#5b21b6", "#a78bfa", "#ede9fe"},
      {"#9a3412", "#fb923c", "#ffedd5"},
      {"#9f1239", "#fb7185", "#ffe4e6"},
      {"#155e75", "#22d3ee", "#cffafe"}
    ]

    @spec domain_colors(non_neg_integer(), :light | :dark) ::
            {String.t(), String.t(), String.t()}
    defp domain_colors(idx, :light), do: Enum.at(@light_palette, rem(idx, length(@light_palette)))
    defp domain_colors(idx, :dark), do: Enum.at(@dark_palette, rem(idx, length(@dark_palette)))
  end
end
