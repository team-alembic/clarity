defmodule Clarity.TreeComponent do
  @moduledoc """
  A lazy-loading navigation tree component that only renders visible nodes.

  Module-named vertices are labelled in the `:name_style` the parent passes
  (see `Clarity.Vertex.Name`); their hints keep the qualified name.

  Like a file explorer, each vertex is shown with its type icon in its colour,
  and its children are grouped by edge label (actions, attributes, …) under
  plain, collapsible group rows, like folders.

  A node is open when it is on the breadcrumb path or the user expanded it,
  unless the user has collapsed it; a group is open unless the user has
  collapsed it. The parent owns both sets so they survive graph updates, and
  when the path changes it drops the collapses along it (see `path_ids/2`),
  revealing the newly current vertex.

  A vertex the lens has no tabs for (see the lens's `contents`) is greyed out,
  though it still opens and links to its page.
  """

  use Clarity.Web, :live_component

  alias Clarity.Content
  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Status.Index
  alias Clarity.Tooltip
  alias Clarity.Vertex
  alias Clarity.Vertex.Name
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  embed_templates "tree_component/*"

  @impl Phoenix.LiveComponent
  def mount(socket) do
    # The parent sets `loading?` while it loads the graph for a new lens or
    # vertex, still passing the previous graph meanwhile.
    {:ok, assign(socket, loading?: false)}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    visible_ids = compute_visible_ids(socket.assigns)
    status_index = Index.build(socket.assigns.graph, socket.assigns.lens)
    providers = Content.providers_for_lens(socket.assigns.lens)

    {:ok,
     assign(socket, visible_ids: visible_ids, status_index: status_index, providers: providers)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle", %{"vertex_id" => vertex_id, "open" => true}, socket) do
    %{opened: opened, collapsed: collapsed} = socket.assigns

    set_tree_state(socket, MapSet.put(opened, vertex_id), MapSet.delete(collapsed, vertex_id))
  end

  def handle_event("toggle", %{"vertex_id" => vertex_id, "open" => false}, socket) do
    %{opened: opened, collapsed: collapsed} = socket.assigns

    set_tree_state(socket, MapSet.delete(opened, vertex_id), MapSet.put(collapsed, vertex_id))
  end

  def handle_event("toggle_group", %{"group_id" => group_id, "open" => open}, socket)
      when is_boolean(open) do
    %{opened: opened, collapsed: collapsed} = socket.assigns

    collapsed =
      if open,
        do: MapSet.delete(collapsed, group_id),
        else: MapSet.put(collapsed, group_id)

    set_tree_state(socket, opened, collapsed)
  end

  @doc """
  Returns the id of the group of `vertex`'s children joined by `label` edges.
  """
  @spec group_id(Vertex.t(), term()) :: String.t()
  def group_id(vertex, label), do: "#{Vertex.id(vertex)}/#{label}"

  @doc """
  Returns the ids of the nodes and groups that must be open to show the last
  of `breadcrumbs`.
  """
  @spec path_ids(Graph.t(), [Vertex.t()]) :: MapSet.t(String.t())
  def path_ids(graph, breadcrumbs) do
    group_ids =
      breadcrumbs
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.flat_map(fn [parent, child] ->
        child_id = Vertex.id(child)

        for {label, children} <- Graph.navigation_children(graph, parent),
            Enum.any?(children, &(Vertex.id(&1) == child_id)),
            do: group_id(parent, label)
      end)

    breadcrumbs
    |> MapSet.new(&Vertex.id/1)
    |> MapSet.union(MapSet.new(group_ids))
  end

  @spec set_tree_state(Socket.t(), MapSet.t(), MapSet.t()) :: {:noreply, Socket.t()}
  defp set_tree_state(socket, opened, collapsed) do
    # Notify parent to persist the tree state
    send(self(), {:update_tree_state, opened, collapsed})

    socket = assign(socket, opened: opened, collapsed: collapsed)

    {:noreply, assign(socket, visible_ids: compute_visible_ids(socket.assigns))}
  end

  attr :graph, :any, required: true
  attr :vertex, :any, required: true
  attr :visible_ids, :any, required: true
  attr :collapsed, :any, required: true
  attr :active_vertex, :any, required: true
  attr :prefix, :string, required: true
  attr :lens, Lens, required: true
  attr :myself, :any, required: true
  attr :name_style, :atom, required: true
  attr :status_index, :any, required: true
  attr :providers, :list, required: true, doc: "The content providers whose tabs the lens shows"

  attr :root?, :boolean,
    default: false,
    doc: "Whether these are the top-level rows, which draw no guide"

  @spec render_vertex(map()) :: Rendered.t()
  def render_vertex(assigns)

  attr :graph, :any, required: true
  attr :vertex, :any, required: true
  attr :visible_ids, :any, required: true
  attr :collapsed, :any, required: true
  attr :active_vertex, :any, required: true
  attr :prefix, :string, required: true
  attr :lens, Lens, required: true
  attr :myself, :any, required: true
  attr :name_style, :atom, required: true
  attr :name, :string, required: true, doc: "The vertex's name among its siblings"
  attr :any_sibling_has_children, :boolean, required: true
  attr :status_index, :any, required: true
  attr :providers, :list, required: true, doc: "The content providers whose tabs the lens shows"

  @spec render_node(map()) :: Rendered.t()
  def render_node(assigns)

  attr :group, :map, required: true
  attr :class, :any, default: nil
  attr :graph, :any, required: true
  attr :visible_ids, :any, required: true
  attr :collapsed, :any, required: true
  attr :active_vertex, :any, required: true
  attr :prefix, :string, required: true
  attr :lens, Lens, required: true
  attr :myself, :any, required: true
  attr :name_style, :atom, required: true
  attr :status_index, :any, required: true
  attr :providers, :list, required: true, doc: "The content providers whose tabs the lens shows"

  @spec group_items(assigns :: Socket.assigns()) :: Rendered.t()
  defp group_items(assigns) do
    ~H"""
    <ul class={@class}>
      <li :for={{child, name} <- @group.children}>
        <.render_node
          vertex={child}
          name={name}
          any_sibling_has_children={@group.any_has_children?}
          {tree_assigns(assigns)}
        />
      </li>
    </ul>
    """
  end

  # The assigns every level of the tree passes down unchanged.
  @spec tree_assigns(map()) :: map()
  defp tree_assigns(assigns) do
    Map.take(assigns, [
      :graph,
      :visible_ids,
      :collapsed,
      :active_vertex,
      :prefix,
      :lens,
      :myself,
      :name_style,
      :status_index,
      :providers
    ])
  end

  attr :vertex, :any, required: true
  attr :active_vertex, :any, required: true
  attr :prefix, :string, required: true
  attr :lens, Lens, required: true
  attr :name, :string, required: true
  attr :providers, :list, required: true

  # A vertex's label: its type icon, in its colour, then its name and any
  # detail (Clarity.Vertex.DetailProvider), muted. Cut short with an ellipsis
  # rather than wrapped, the detail first; the hover hint has it all. A vertex
  # the lens has no tabs for is greyed out.
  @spec node_link(map()) :: Rendered.t()
  defp node_link(assigns) do
    assigns =
      assign(assigns,
        type_icon: Tooltip.type_icon(assigns.vertex),
        detail: Vertex.DetailProvider.detail(assigns.vertex),
        empty?: not Content.any_applies?(assigns.providers, assigns.vertex, assigns.lens)
      )

    ~H"""
    <.link
      patch={Path.join([@prefix, @lens.id, Vertex.id(@vertex)])}
      aria-current={@vertex == @active_vertex && "page"}
      {Tooltip.attrs(@vertex)}
      class={[
        "flex min-w-0 items-center gap-1 px-1 py-px rounded-xs hover:bg-base-light-200 dark:hover:bg-base-dark-700 hover:text-primary-light dark:hover:text-primary-dark transition-colors font-medium",
        @empty? && "tree-empty",
        @vertex == @active_vertex &&
          "bg-primary-light dark:bg-primary-dark text-white dark:text-base-dark-900"
      ]}
    >
      <svg class="tree-icon" data-tone={@type_icon.tone} aria-hidden="true">
        <use href={"#clarity-icon-#{@type_icon.icon}"} />
      </svg>
      <.vertex_name
        vertex={@vertex}
        name={@name}
        class={["tree-name truncate", @detail && "shrink-0"]}
      />
      <span :if={@detail} class="tree-detail truncate">{@detail}</span>
    </.link>
    """
  end

  attr :entry, :any, default: nil
  attr :prefix, :string, required: true
  attr :lens, Lens, required: true

  # A badge links to its worst issue: that issue's vertex, on the tab that
  # explains its status class (see PageLive's vertex route).
  @doc false
  @spec status_badge(map()) :: Rendered.t()
  def status_badge(assigns) do
    ~H"""
    <%= if @entry do %>
      <.link
        patch={badge_path(@prefix, @lens, hd(@entry.issues))}
        class={[
          "inline-flex shrink-0 items-center gap-1 ml-1.5 px-1.5 py-0.5 rounded-full align-middle",
          "text-xs font-medium leading-none ring-1 ring-inset hover:ring-2",
          badge_classes(@entry.severity)
        ]}
        aria-label={badge_label(@entry)}
        {badge_hint(@entry)}
      >
        <%= case @entry.severity do %>
          <% :error -> %>
            <.icon_error class="w-3 h-3" />
          <% :warning -> %>
            <.icon_warning class="w-3 h-3" />
          <% :info -> %>
            <.icon_info class="w-3 h-3" />
        <% end %>
        <span :if={@entry.count > 0} class="tabular-nums">{@entry.count}</span>
      </.link>
    <% end %>
    """
  end

  @spec badge_path(String.t(), Lens.t(), Index.issue()) :: String.t()
  defp badge_path(prefix, lens, issue),
    do:
      Path.join([prefix, lens.id, issue.vertex_id]) <>
        "?" <> URI.encode_query(status: issue.class)

  @spec badge_classes(Clarity.Status.severity()) :: String.t()
  defp badge_classes(:error),
    do:
      "bg-red-100 text-red-700 ring-red-600/20 dark:bg-red-500/15 dark:text-red-300 dark:ring-red-400/30"

  defp badge_classes(:warning),
    do:
      "bg-yellow-100 text-yellow-800 ring-yellow-600/20 dark:bg-yellow-500/15 dark:text-yellow-300 dark:ring-yellow-400/30"

  defp badge_classes(:info),
    do:
      "bg-blue-100 text-blue-700 ring-blue-600/20 dark:bg-blue-500/15 dark:text-blue-300 dark:ring-blue-400/30"

  # The badge's hint says what is wrong, here and beneath, worst first, so there
  # is no need to open the subtree to find out: how many issues of each
  # severity, then each issue's vertex and message.
  @spec badge_hint(Index.entry()) :: keyword(String.t())
  defp badge_hint(entry) do
    [
      "data-tooltip-title": count_noun(issue_total(entry), "issue"),
      "data-tooltip-badges": JSON.encode!(severity_counts(entry)),
      "data-tooltip-facts": JSON.encode!(Enum.map(entry.issues, &[&1.name, issue_line(&1)]))
    ] ++ Enum.map(issues_left_out(entry), &{:"data-tooltip-text", &1})
  end

  @spec badge_label(Index.entry()) :: String.t()
  defp badge_label(entry) do
    summary =
      "#{count_noun(issue_total(entry), "issue")} (#{Enum.join(severity_counts(entry), ", ")})"

    issues = Enum.map_join(entry.issues, "; ", &"#{&1.name}: #{issue_line(&1)}")

    opens = "Opens #{hd(entry.issues).name}"

    Enum.join([summary | issues_left_out(entry)] ++ [issues, opens], ". ")
  end

  @spec issue_line(Index.issue()) :: String.t()
  defp issue_line(issue), do: "#{severity_name(issue.severity)}: #{issue.message}"

  @spec severity_counts(Index.entry()) :: [String.t()]
  defp severity_counts(entry) do
    for severity <- [:error, :warning, :info], count = entry.severities[severity] do
      count_noun(count, String.downcase(severity_name(severity)))
    end
  end

  # When the hint lists only the worst issues, it says so.
  @spec issues_left_out(Index.entry()) :: [String.t()]
  defp issues_left_out(entry) do
    case {length(entry.issues), issue_total(entry)} do
      {shown, total} when shown < total -> ["The worst #{shown} of #{total}:"]
      _all -> []
    end
  end

  @spec issue_total(Index.entry()) :: pos_integer()
  defp issue_total(entry), do: entry.severities |> Map.values() |> Enum.sum()

  @spec severity_name(Clarity.Status.severity()) :: String.t()
  defp severity_name(:error), do: "Error"
  defp severity_name(:warning), do: "Warning"
  defp severity_name(:info), do: "Info"

  @spec count_noun(pos_integer(), String.t()) :: String.t()
  defp count_noun(count, noun) when count == 1 or noun == "info", do: "#{count} #{noun}"
  defp count_noun(count, noun), do: "#{count} #{noun}s"

  @spec compute_visible_ids(map()) :: MapSet.t()
  defp compute_visible_ids(assigns) do
    breadcrumb_ids = MapSet.new(assigns.breadcrumbs, &Vertex.id/1)

    breadcrumb_ids
    |> MapSet.union(assigns.opened)
    |> MapSet.difference(assigns.collapsed)
  end

  # Children are named together, so siblings whose names clash are told apart.
  @spec navigation_groups(Graph.t(), Vertex.t(), MapSet.t(), Name.style(), Vertex.t(), MapSet.t()) ::
          [map()]
  defp navigation_groups(graph, vertex, collapsed, name_style, active_vertex, visible_ids) do
    active_id = Vertex.id(active_vertex)
    # An open current vertex has its own guide active instead (see current?/2).
    active_is_open? = open?(active_vertex, visible_ids) and has_children?(graph, active_vertex)

    groups = graph |> Graph.navigation_children(vertex) |> Enum.sort_by(&group_order/1)

    for {label, children} <- groups, label != :content do
      id = group_id(vertex, label)

      %{
        id: id,
        label: label,
        children: sort_by_label(Enum.zip(children, Name.display_all(children, name_style))),
        open?: not MapSet.member?(collapsed, id),
        active?: not active_is_open? and Enum.any?(children, &(Vertex.id(&1) == active_id)),
        any_has_children?: Enum.any?(children, &has_children?(graph, &1))
      }
    end
  end

  # Rows go in the order of the labels they show, ignoring case, rather than
  # of their vertices' full names.
  @spec sort_by_label([{Vertex.t(), String.t()}]) :: [{Vertex.t(), String.t()}]
  defp sort_by_label(children),
    do:
      Enum.sort_by(children, fn {child, label} ->
        {String.downcase(label), label, Vertex.name(child)}
      end)

  # Groups go in alphabetical order, but modules last: there are many, and
  # they repeat the domains, resources and the like in the groups above.
  @spec group_order({term(), [Vertex.t()]}) :: {boolean(), String.t()}
  defp group_order({label, _children}), do: {label == :module, to_string(label)}

  # The active guide stays visible; see render_vertex.html.heex.
  @spec guide_class(boolean()) :: [String.t() | false]
  defp guide_class(active?), do: ["tree-children", active? && "tree-guide-active"]

  @spec current?(Vertex.t(), Vertex.t()) :: boolean()
  defp current?(vertex, active_vertex), do: Vertex.id(vertex) == Vertex.id(active_vertex)

  @spec has_children?(Graph.t(), Vertex.t()) :: boolean()
  defp has_children?(graph, vertex) do
    children = Graph.navigation_children(graph, vertex)
    Enum.any?(children, fn {label, vertices} -> label != :content and vertices != [] end)
  end

  @spec open?(Vertex.t(), MapSet.t()) :: boolean()
  defp open?(vertex, visible_ids) do
    MapSet.member?(visible_ids, Vertex.id(vertex))
  end
end
