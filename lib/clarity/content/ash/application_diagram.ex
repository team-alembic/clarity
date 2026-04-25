with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.ApplicationDiagram do
    @moduledoc """
    Visual diagram of all Ash resources in an application.

    Resources are rendered as boxes labelled with the short module name.
    A domain legend acts as the colour key and is always shown first
    (positionable at the top or on the left).

    Two layouts are available:

      * `:cluster` (default) — resources are placed inside per-domain
        containers; the cluster fill provides the domain colour.
      * `:color` — resources are laid out in a horizontally-packed grid,
        each filled with its domain's colour.
    """

    @behaviour Clarity.Content

    use Clarity.Web, :live_component

    alias Clarity.Vertex.Application
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Util

    @impl Clarity.Content
    def name, do: "Application Diagram"

    @impl Clarity.Content
    def description, do: "Visual map of all Ash resources, grouped by domain"

    @impl Clarity.Content
    def sort_priority, do: -90

    @impl Clarity.Content
    def applies?(%Application{app: app}, _lens) do
      Ash.Info.domains(app) != []
    end

    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Application{app: app}, _lens) do
      # Used by the raw-content drawer fallback. Always cluster + top legend.
      {:viz, fn %{theme: theme} -> to_dot(app, theme, :cluster, :top) end}
    end

    @impl Phoenix.LiveComponent
    def mount(socket) do
      {:ok, assign(socket, mode: :cluster, legend: :top)}
    end

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      {:ok, assign(socket, assigns)}
    end

    @impl Phoenix.LiveComponent
    def handle_event("set_mode", %{"mode" => "cluster"}, socket),
      do: {:noreply, assign(socket, mode: :cluster)}

    def handle_event("set_mode", %{"mode" => "color"}, socket),
      do: {:noreply, assign(socket, mode: :color)}

    def handle_event("set_legend", %{"position" => "top"}, socket),
      do: {:noreply, assign(socket, legend: :top)}

    def handle_event("set_legend", %{"position" => "left"}, socket),
      do: {:noreply, assign(socket, legend: :left)}

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <div class="content flex flex-col h-full relative">
        <div class="absolute top-4 right-4 z-10 flex flex-col gap-2 items-end">
          <div class="flex gap-1 bg-base-light-100 dark:bg-base-dark-800 shadow-md border border-base-light-300 dark:border-base-dark-700 p-1">
            <button
              type="button"
              phx-click="set_mode"
              phx-value-mode="cluster"
              phx-target={@myself}
              aria-pressed={if(@mode == :cluster, do: "true", else: "false")}
              class={toggle_class(@mode == :cluster)}
            >
              Grouped
            </button>
            <button
              type="button"
              phx-click="set_mode"
              phx-value-mode="color"
              phx-target={@myself}
              aria-pressed={if(@mode == :color, do: "true", else: "false")}
              class={toggle_class(@mode == :color)}
            >
              Coloured
            </button>
          </div>
          <div class="flex gap-1 bg-base-light-100 dark:bg-base-dark-800 shadow-md border border-base-light-300 dark:border-base-dark-700 p-1">
            <span class="px-2 py-1.5 text-xs uppercase tracking-wide text-base-light-500 dark:text-base-dark-400 self-center">
              Legend
            </span>
            <button
              type="button"
              phx-click="set_legend"
              phx-value-position="top"
              phx-target={@myself}
              aria-pressed={if(@legend == :top, do: "true", else: "false")}
              class={toggle_class(@legend == :top)}
            >
              Top
            </button>
            <button
              type="button"
              phx-click="set_legend"
              phx-value-position="left"
              phx-target={@myself}
              aria-pressed={if(@legend == :left, do: "true", else: "false")}
              class={toggle_class(@legend == :left)}
            >
              Left
            </button>
          </div>
        </div>
        <div class="flex-1 min-h-0 p-4">
          <.viz
            graph={to_dot(@vertex.app, @theme, @mode, @legend)}
            engine={@engine}
            id="application-diagram-viz"
            class="h-full"
          />
        </div>
      </div>
      """
    end

    @spec toggle_class(active? :: boolean()) :: String.t()
    defp toggle_class(true),
      do: "px-3 py-1.5 text-sm font-semibold bg-primary-light dark:bg-primary-dark text-white"

    defp toggle_class(false),
      do:
        "px-3 py-1.5 text-sm font-semibold text-base-light-700 dark:text-base-dark-300 hover:bg-base-light-200 dark:hover:bg-base-dark-700"

    @spec to_dot(
            app :: atom(),
            theme :: :light | :dark,
            mode :: :cluster | :color,
            legend :: :top | :left
          ) :: iodata()
    defp to_dot(app, theme, mode, legend) when is_atom(app) do
      domains_and_resources = Ash.Info.domains_and_resources(app)
      indexed = Enum.with_index(domains_and_resources)
      total_resources = Enum.sum_by(indexed, fn {{_, r}, _} -> length(r) end)

      {fg, edge_color} = base_colors(theme)

      [
        "digraph {\n",
        "  bgcolor=transparent;\n",
        "  fontname=\"system-ui\";\n",
        ~s|  fontcolor="#{fg}";\n|,
        "  rankdir=",
        rankdir(legend),
        ";\n",
        "  compound=true;\n",
        "  nodesep=0.25;\n",
        "  ranksep=0.45;\n",
        "  pack=true;\n",
        "  packmode=\"array_t#{packing_columns(total_resources, mode)}\";\n",
        node_defaults(theme),
        edge_defaults(edge_color),
        legend_block(indexed, theme, legend),
        body(indexed, theme, mode),
        legend_anchors(indexed, mode),
        "}\n"
      ]
    end

    @spec rankdir(:top | :left) :: String.t()
    defp rankdir(:top), do: "TB"
    defp rankdir(:left), do: "LR"

    # Approx columns for `array_t<N>` pack mode. More columns = wider layout.
    @spec packing_columns(non_neg_integer(), :cluster | :color) :: pos_integer()
    defp packing_columns(_total, :cluster), do: 4
    defp packing_columns(total, :color) when total <= 6, do: max(total, 1)
    defp packing_columns(total, :color), do: ceil(:math.sqrt(total) + 1)

    @spec node_defaults(:light | :dark) :: iodata()
    defp node_defaults(theme) do
      {fg, _edge} = base_colors(theme)

      [
        ~s|  node [|,
        ~s|shape=box, |,
        ~s|style=filled, |,
        ~s|fontname="system-ui", |,
        ~s|fontsize=14, |,
        ~s|penwidth=1.4, |,
        ~s|height=0.5, |,
        ~s|margin="0.18,0.08", |,
        ~s|fontcolor="#{fg}"|,
        ~s|];\n|
      ]
    end

    @spec edge_defaults(String.t()) :: iodata()
    defp edge_defaults(color) do
      ~s|  edge [color="#{color}", style=invis];\n|
    end

    @spec body([{{module(), [module()]}, non_neg_integer()}], :light | :dark, :cluster | :color) ::
            iodata()
    defp body(indexed, theme, :cluster) do
      Enum.map(indexed, fn {{domain, resources}, idx} ->
        cluster(domain, resources, theme, idx)
      end)
    end

    defp body(indexed, theme, :color) do
      Enum.flat_map(indexed, fn {{_domain, resources}, idx} ->
        Enum.map(resources, &colored_node(&1, theme, idx))
      end)
    end

    @spec cluster(module(), [module()], :light | :dark, non_neg_integer()) :: iodata()
    defp cluster(domain, resources, theme, idx) do
      {fill, stroke, fg} = domain_colors(idx, theme)

      [
        "subgraph ",
        cluster_id(domain),
        " {\n",
        ~s|  label="|,
        domain_label(domain),
        ~s|";\n|,
        ~s|  style=filled;\n|,
        ~s|  fillcolor="#{fill}";\n|,
        ~s|  color="#{stroke}";\n|,
        ~s|  fontcolor="#{fg}";\n|,
        ~s|  fontsize=13;\n|,
        ~s|  fontname="system-ui Bold";\n|,
        ~s|  penwidth=2;\n|,
        ~s|  margin=14;\n|,
        Enum.map(resources, fn resource -> neutral_node(resource, theme) end),
        "}\n"
      ]
    end

    @spec colored_node(module(), :light | :dark, non_neg_integer()) :: iodata()
    defp colored_node(resource, theme, idx) do
      {fill, stroke, fg} = domain_colors(idx, theme)

      [
        node_id(resource),
        ~s| [label="|,
        short_name(resource),
        ~s|", |,
        ~s|fillcolor="#{fill}", |,
        ~s|color="#{stroke}", |,
        ~s|fontcolor="#{fg}", |,
        ~s|URL="##{Util.id(Resource, [resource])}"];\n|
      ]
    end

    @spec neutral_node(module(), :light | :dark) :: iodata()
    defp neutral_node(resource, theme) do
      {bg, fg, stroke} = neutral_colors(theme)

      [
        node_id(resource),
        ~s| [label="|,
        short_name(resource),
        ~s|", |,
        ~s|fillcolor="#{bg}", |,
        ~s|color="#{stroke}", |,
        ~s|fontcolor="#{fg}", |,
        ~s|URL="##{Util.id(Resource, [resource])}"];\n|
      ]
    end

    @spec legend_block(
            [{{module(), [module()]}, non_neg_integer()}],
            :light | :dark,
            :top | :left
          ) :: iodata()
    defp legend_block(indexed, theme, position) do
      {bg, fg, stroke} = neutral_colors(theme)

      rank_attr =
        case position do
          :top -> "  rank=source;\n"
          :left -> "  rank=min;\n"
        end

      [
        "subgraph cluster_legend {\n",
        ~s|  label="Domains";\n|,
        ~s|  style=filled;\n|,
        ~s|  fillcolor="#{bg}";\n|,
        ~s|  color="#{stroke}";\n|,
        ~s|  fontcolor="#{fg}";\n|,
        ~s|  fontsize=12;\n|,
        ~s|  fontname="system-ui Bold";\n|,
        ~s|  margin=12;\n|,
        rank_attr,
        Enum.map(indexed, fn {{domain, _resources}, idx} ->
          {fill, dstroke, dfg} = domain_colors(idx, theme)

          [
            "  ",
            legend_id(domain),
            ~s| [label="|,
            domain_label(domain),
            ~s|", |,
            ~s|fillcolor="#{fill}", |,
            ~s|color="#{dstroke}", |,
            ~s|fontcolor="#{dfg}"];\n|
          ]
        end),
        # Force legend entries onto a single rank so they render as a row
        ~s|  {rank=same; |,
        Enum.map_intersperse(indexed, "; ", fn {{domain, _r}, _idx} -> legend_id(domain) end),
        ";}\n",
        "}\n"
      ]
    end

    # Invisible edges from the legend entries to one resource each, to anchor
    # the legend ABOVE (for :top rankdir TB) or LEFT-OF (for :left rankdir LR)
    # the diagram body. Anchors only added in :cluster mode where we have
    # one cluster per domain to anchor to. For :color mode the array packing
    # already produces a tight grid; the legend simply packs as one of the
    # components.
    @spec legend_anchors(
            [{{module(), [module()]}, non_neg_integer()}],
            :cluster | :color
          ) :: iodata()
    defp legend_anchors(_indexed, :color), do: []

    defp legend_anchors(indexed, :cluster) do
      Enum.flat_map(indexed, fn {{domain, resources}, _idx} ->
        case resources do
          [first | _] ->
            [[legend_id(domain), " -> ", node_id(first), ";\n"]]

          [] ->
            []
        end
      end)
    end

    @spec node_id(module()) :: iodata()
    defp node_id(resource), do: ["res_", safe_id(inspect(resource))]

    @spec cluster_id(module()) :: iodata()
    defp cluster_id(domain), do: ["cluster_dom_", safe_id(inspect(domain))]

    @spec legend_id(module()) :: iodata()
    defp legend_id(domain), do: ["legend_", safe_id(inspect(domain))]

    @spec safe_id(String.t()) :: String.t()
    defp safe_id(name), do: String.replace(name, ~r/[^A-Za-z0-9]/, "_")

    @spec short_name(module()) :: String.t()
    defp short_name(module), do: module |> Module.split() |> List.last()

    @spec domain_label(module()) :: String.t()
    defp domain_label(module), do: inspect(module)

    # 8-entry palettes. Each entry is `{fill, stroke, foreground}` chosen
    # for AAA-ish text contrast inside the filled box.
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

    # `{background, foreground, stroke}` for resource boxes in cluster mode.
    @spec neutral_colors(:light | :dark) :: {String.t(), String.t(), String.t()}
    defp neutral_colors(:light), do: {"#ffffff", "#0f172a", "#475569"}
    defp neutral_colors(:dark), do: {"#1e293b", "#f8fafc", "#94a3b8"}

    # `{foreground, edge_color}` for top-level graph attrs.
    @spec base_colors(:light | :dark) :: {String.t(), String.t()}
    defp base_colors(:light), do: {"#0f172a", "#94a3b8"}
    defp base_colors(:dark), do: {"#f8fafc", "#475569"}
  end
end
