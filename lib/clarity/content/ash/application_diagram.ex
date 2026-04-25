with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.ApplicationDiagram do
    @moduledoc """
    Visual diagram of all Ash resources in an application.

    Resources are rendered as boxes labelled with the short module name.
    Two layouts are available:

      * `:cluster` (default) — resources are placed inside a labelled
        rounded container per domain.
      * `:color` — resources are laid out flat and colour-coded by domain,
        with a legend at the top.
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
      # The live_component drives the actual rendering with mode toggles.
      # render_static is only used for the raw-content drawer fallback,
      # which always uses :cluster mode.
      {:viz, fn %{theme: theme} -> to_dot(app, theme, :cluster) end}
    end

    @impl Phoenix.LiveComponent
    def mount(socket) do
      {:ok, assign(socket, mode: :cluster)}
    end

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      {:ok, assign(socket, assigns)}
    end

    @impl Phoenix.LiveComponent
    def handle_event("set_mode", %{"mode" => "cluster"}, socket) do
      {:noreply, assign(socket, mode: :cluster)}
    end

    def handle_event("set_mode", %{"mode" => "color"}, socket) do
      {:noreply, assign(socket, mode: :color)}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <div class="content flex flex-col h-full relative">
        <div class="absolute top-4 right-4 z-10 flex gap-1 bg-base-light-100 dark:bg-base-dark-800 rounded-md shadow-md border border-base-light-300 dark:border-base-dark-700 p-1">
          <button
            type="button"
            phx-click="set_mode"
            phx-value-mode="cluster"
            phx-target={@myself}
            aria-pressed={if(@mode == :cluster, do: "true", else: "false")}
            class={[
              "px-3 py-1.5 text-sm rounded transition-colors",
              if(@mode == :cluster,
                do: "bg-primary-light dark:bg-primary-dark text-white",
                else:
                  "text-base-light-700 dark:text-base-dark-300 hover:bg-base-light-200 dark:hover:bg-base-dark-700"
              )
            ]}
          >
            Grouped
          </button>
          <button
            type="button"
            phx-click="set_mode"
            phx-value-mode="color"
            phx-target={@myself}
            aria-pressed={if(@mode == :color, do: "true", else: "false")}
            class={[
              "px-3 py-1.5 text-sm rounded transition-colors",
              if(@mode == :color,
                do: "bg-primary-light dark:bg-primary-dark text-white",
                else:
                  "text-base-light-700 dark:text-base-dark-300 hover:bg-base-light-200 dark:hover:bg-base-dark-700"
              )
            ]}
          >
            Coloured
          </button>
        </div>
        <div class="flex-1 min-h-0 p-4">
          <.viz
            graph={to_dot(@vertex.app, @theme, @mode)}
            id="application-diagram-viz"
            class="h-full"
          />
        </div>
      </div>
      """
    end

    @spec to_dot(app :: atom(), theme :: :light | :dark, mode :: :cluster | :color) :: iodata()
    defp to_dot(app, theme, mode) when is_atom(app) do
      domains_and_resources = Ash.Info.domains_and_resources(app)
      indexed = Enum.with_index(domains_and_resources)

      [
        "digraph {\n",
        "  bgcolor = transparent;\n",
        "  fontname = \"system-ui\";\n",
        "  rankdir = LR;\n",
        "  compound = true;\n",
        "  graph [nodesep=0.4, ranksep=0.8];\n",
        node_defaults(theme),
        body(indexed, theme, mode),
        "}\n"
      ]
    end

    @spec node_defaults(:light | :dark) :: iodata()
    defp node_defaults(:light) do
      ~s|  node [shape=box, style="filled,rounded", fontname="system-ui", color="#94a3b8"];\n|
    end

    defp node_defaults(:dark) do
      ~s|  node [shape=box, style="filled,rounded", fontname="system-ui", color="#9ca3af", fontcolor="#f9fafb"];\n|
    end

    @spec body([{{module(), [module()]}, non_neg_integer()}], :light | :dark, :cluster | :color) ::
            iodata()
    defp body(indexed, theme, :cluster) do
      Enum.map(indexed, fn {{domain, resources}, idx} ->
        cluster(domain, resources, theme, idx)
      end)
    end

    defp body(indexed, theme, :color) do
      [
        legend(indexed, theme),
        "\n",
        Enum.flat_map(indexed, fn {{domain, resources}, idx} ->
          Enum.map(resources, fn resource ->
            colored_node(resource, domain, theme, idx)
          end)
        end)
      ]
    end

    @spec cluster(module(), [module()], :light | :dark, non_neg_integer()) :: iodata()
    defp cluster(domain, resources, theme, idx) do
      {fill, stroke, fg} = domain_colors(idx, theme)

      [
        "subgraph ",
        cluster_id(domain),
        " {\n",
        ~s|  label = "|,
        domain_label(domain),
        ~s|";\n|,
        ~s|  style = "filled,rounded";\n|,
        "  fillcolor = \"",
        fill,
        "\";\n",
        "  color = \"",
        stroke,
        "\";\n",
        "  fontcolor = \"",
        fg,
        "\";\n",
        ~s|  fontsize = 12;\n|,
        ~s|  margin = 16;\n|,
        Enum.map(resources, fn resource ->
          neutral_node(resource, theme)
        end),
        "}\n"
      ]
    end

    @spec colored_node(module(), module(), :light | :dark, non_neg_integer()) :: iodata()
    defp colored_node(resource, _domain, theme, idx) do
      {fill, stroke, fg} = domain_colors(idx, theme)

      [
        node_id(resource),
        ~s| [label="|,
        short_name(resource),
        ~s|", fillcolor="|,
        fill,
        ~s|", color="|,
        stroke,
        ~s|", fontcolor="|,
        fg,
        ~s|", URL="#|,
        Util.id(Resource, [resource]),
        ~s|"];\n|
      ]
    end

    @spec neutral_node(module(), :light | :dark) :: iodata()
    defp neutral_node(resource, theme) do
      {bg, fg} = neutral_colors(theme)

      [
        node_id(resource),
        ~s| [label="|,
        short_name(resource),
        ~s|", fillcolor="|,
        bg,
        ~s|", fontcolor="|,
        fg,
        ~s|", URL="#|,
        Util.id(Resource, [resource]),
        ~s|"];\n|
      ]
    end

    @spec legend([{{module(), [module()]}, non_neg_integer()}], :light | :dark) :: iodata()
    defp legend(indexed, theme) do
      {bg, _fg} = neutral_colors(theme)

      [
        "subgraph cluster_legend {\n",
        ~s|  label = "Domains";\n|,
        ~s|  style = "filled,rounded";\n|,
        ~s|  fillcolor = "|,
        bg,
        ~s|";\n|,
        ~s|  fontsize = 11;\n|,
        ~s|  margin = 10;\n|,
        ~s|  rank = source;\n|,
        Enum.map(indexed, fn {{domain, _resources}, idx} ->
          {fill, stroke, fg} = domain_colors(idx, theme)

          [
            "  ",
            legend_id(domain),
            ~s| [label="|,
            domain_label(domain),
            ~s|", shape=box, style="filled,rounded", fillcolor="|,
            fill,
            ~s|", color="|,
            stroke,
            ~s|", fontcolor="|,
            fg,
            ~s|"];\n|
          ]
        end),
        "}\n"
      ]
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

    # Distinct, accessible palettes per theme. Index wraps if there are more
    # domains than colours. Each entry is `{fill, stroke, foreground}`.
    @light_palette [
      {"#fde68a", "#a16207", "#1f2937"},
      {"#bbf7d0", "#15803d", "#1f2937"},
      {"#bae6fd", "#0369a1", "#1f2937"},
      {"#fbcfe8", "#be185d", "#1f2937"},
      {"#ddd6fe", "#6d28d9", "#1f2937"},
      {"#fed7aa", "#c2410c", "#1f2937"},
      {"#fecdd3", "#be123c", "#1f2937"},
      {"#d1fae5", "#047857", "#1f2937"}
    ]

    @dark_palette [
      {"#78350f", "#fbbf24", "#fef3c7"},
      {"#14532d", "#4ade80", "#dcfce7"},
      {"#0c4a6e", "#38bdf8", "#e0f2fe"},
      {"#831843", "#f472b6", "#fce7f3"},
      {"#4c1d95", "#a78bfa", "#ede9fe"},
      {"#7c2d12", "#fb923c", "#fed7aa"},
      {"#881337", "#fb7185", "#ffe4e6"},
      {"#064e3b", "#34d399", "#d1fae5"}
    ]

    @spec domain_colors(non_neg_integer(), :light | :dark) ::
            {String.t(), String.t(), String.t()}
    defp domain_colors(idx, :light), do: Enum.at(@light_palette, rem(idx, length(@light_palette)))
    defp domain_colors(idx, :dark), do: Enum.at(@dark_palette, rem(idx, length(@dark_palette)))

    @spec neutral_colors(:light | :dark) :: {String.t(), String.t()}
    defp neutral_colors(:light), do: {"#ffffff", "#1f2937"}
    defp neutral_colors(:dark), do: {"#1f2937", "#f9fafb"}
  end
end
