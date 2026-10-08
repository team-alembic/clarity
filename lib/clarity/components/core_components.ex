defmodule Clarity.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  import Clarity.Components.MarkdownComponent
  import Clarity.IconComponents

  alias Clarity.Content
  alias Clarity.Perspective.Lens
  alias Clarity.Tooltip
  alias Clarity.Vertex
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  embed_templates "core_components/*"

  attr :socket, Socket, required: true, doc: "The LiveView socket"
  attr :prefix, :string, default: "/", doc: "The URL prefix for links"
  attr :clarity_pid, :any, required: true, doc: "PID of the Clarity server process"
  attr :class, :string, default: "", doc: "CSS classes to apply to the header container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the header container"

  @spec header(assigns :: Socket.assigns()) :: Rendered.t()
  def header(assigns)

  @doc """
  Renders the activity bar: icons down the left edge, as in VS Code. There is
  one per lens, each a role's filtered view of the graph, then Reports, which
  is always there too, so no report is hidden behind a lens choice. The current
  icon shows or hides the sidebar; another lens's icon explores through that
  lens, and Reports goes to the reports. While exploring, a lens's icon sends
  the page a `switch_lens` event (with `lens`, its id), so the page can keep the
  selected vertex.
  """
  attr :prefix, :string, required: true, doc: "The URL prefix for links"
  attr :lenses, :list, required: true, doc: "Every lens, in the order shown"
  attr :lens, Lens, default: nil, doc: "The lens explored through; nil on the reports"
  attr :section, :atom, required: true, values: [:explore, :reports], doc: "The section shown"

  @spec activity_bar(assigns :: Socket.assigns()) :: Rendered.t()
  def activity_bar(assigns) do
    ~H"""
    <nav id="activity-bar" class="activity-bar" aria-label="Lenses and reports">
      <.activity_item
        :for={lens <- @lenses}
        id={"activity-lens-#{lens.id}"}
        label={lens.name}
        current={@section == :explore and @lens != nil and lens.id == @lens.id}
        switch_lens={@section == :explore && lens.id}
        to={Path.join([@prefix, lens.id])}
      >
        <span class="flex size-6 items-center justify-center text-xl leading-none">
          {lens.icon.()}
        </span>
      </.activity_item>
      <hr class="activity-divider" />
      <.activity_item
        id="activity-reports"
        label="Reports"
        current={@section == :reports}
        to={Path.join([@prefix, "reports"])}
      >
        <.icon_report class="size-6" />
      </.activity_item>
    </nav>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :current, :boolean, required: true
  attr :switch_lens, :any, default: false, doc: "A lens id to send `switch_lens` with, or false"
  attr :to, :string, required: true
  slot :inner_block, required: true

  # The current item toggles the sidebar (the NavPanel hook listens for
  # clarity:toggle-nav, as for ⌘B). While exploring, a lens's item asks the page
  # to switch lens, keeping the selected vertex; otherwise an item navigates,
  # crossing between exploring and the reports.
  @spec activity_item(map()) :: Rendered.t()
  defp activity_item(%{current: true} = assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      class="activity-item"
      aria-current="page"
      aria-label={"#{@label}: show or hide the sidebar"}
      phx-click={JS.dispatch("clarity:toggle-nav")}
      {Tooltip.attrs("#{@label} · show or hide the sidebar (⌘B)")}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp activity_item(%{switch_lens: lens_id} = assigns) when is_binary(lens_id) do
    ~H"""
    <button
      id={@id}
      type="button"
      class="activity-item"
      aria-label={@label}
      phx-click="switch_lens"
      phx-value-lens={@switch_lens}
      {Tooltip.attrs(@label)}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp activity_item(assigns) do
    ~H"""
    <.link id={@id} navigate={@to} class="activity-item" aria-label={@label} {Tooltip.attrs(@label)}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :id, :string, required: true, doc: "The unique ID for the visualization element"
  attr :graph, :string, required: true, doc: "The graph data in DOT language format"

  attr :tooltips, :map,
    default: %{},
    doc: "Hover hints keyed by vertex id, see `Clarity.Tooltip.hints/1`"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the graph container"

  @spec viz(assigns :: Socket.assigns()) :: Rendered.t()
  def viz(assigns)

  attr :id, :string, required: true, doc: "The unique ID for the mermaid visualization"
  attr :graph, :string, required: true, doc: "The mermaid graph definition in string format"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the graph container"

  @spec mermaid(assigns :: Socket.assigns()) :: Rendered.t()
  def mermaid(assigns)

  @doc """
  Renders the settings menu: a gear that opens the viewer's preferences, the
  theme (light, dark or the system's), whether names are short where what
  holds them is shown, and how text links names (lowercase ones too, every
  mention). They're kept in the browser, which tells the LiveView.
  """
  attr :id, :string, required: true, doc: "The unique ID for the settings menu"
  attr :class, :string, default: "", doc: "CSS classes to apply to the settings menu"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the settings menu"

  @spec settings_menu(assigns :: Socket.assigns()) :: Rendered.t()
  def settings_menu(assigns)

  attr :flash, :map, default: %{}, doc: "The flash messages to display"
  attr :class, :string, default: "", doc: "CSS classes to apply to the flash container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  @spec flash_group(assigns :: Socket.assigns()) :: Rendered.t()
  def flash_group(assigns)

  @doc """
  Renders the Clarity splash screen with animated logo.
  """
  attr :class, :string, default: nil
  attr :rest, :global

  @spec splash_screen(map()) :: Rendered.t()
  def splash_screen(assigns)

  @doc """
  Renders a spinner where the page will be, while its data loads. It fades in
  only after a moment, so a quick load shows nothing.
  """
  @spec page_loading(assigns :: Socket.assigns()) :: Rendered.t()
  def page_loading(assigns) do
    ~H"""
    <div id="page-loading" class="page-loading" role="status" aria-label="Loading">
      <.icon_spinner class="size-6 animate-spin" />
    </div>
    """
  end

  @doc """
  Renders tab navigation for switching between content views.
  """
  attr :contents, :list, required: true, doc: "List of available content tabs"
  attr :content, Content, doc: "Currently selected content tab"
  attr :prefix, :string, required: true, doc: "URL prefix for links"
  attr :lens, Lens, required: true, doc: "Current lens for navigation"

  attr :vertex, :any,
    required: true,
    doc: "Current vertex being viewed (implements Clarity.Vertex protocol)"

  attr :vertex_status_classes, :map,
    default: %{},
    doc: "Map of the active vertex's status classes to worst severity, for tab flags"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the tabs container"

  @spec tabs(assigns :: Socket.assigns()) :: Rendered.t()
  def tabs(assigns)

  @spec tab_status_severity(Content.t(), %{atom() => Clarity.Status.severity()}) ::
          Clarity.Status.severity() | nil
  defp tab_status_severity(%Content{status_classes: classes}, vertex_status_classes) do
    classes
    |> Enum.map(&Map.get(vertex_status_classes, &1))
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      severities -> Enum.reduce(severities, &Clarity.Status.max_severity/2)
    end
  end

  @spec tab_status_dot(Clarity.Status.severity()) :: String.t()
  defp tab_status_dot(:error), do: "bg-red-500"
  defp tab_status_dot(:warning), do: "bg-yellow-500"
  defp tab_status_dot(:info), do: "bg-blue-500"

  @doc """
  Renders a message where there is nothing to show, or something went wrong:
  an icon, a title, a sentence or two, and optionally a way on.
  """
  attr :title, :string, required: true, doc: "What happened, in a few words"
  attr :class, :any, default: nil, doc: "CSS classes to apply to the container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the container"
  slot :icon, required: true, doc: "An icon, sized by the component"
  slot :inner_block, doc: "What to do about it"
  slot :action, doc: "Links or buttons on from here"

  @spec empty_state(assigns :: Socket.assigns()) :: Rendered.t()
  def empty_state(assigns)

  @doc """
  Renders an error page when a lens cannot be found.
  """
  attr :prefix, :string, required: true, doc: "URL prefix for navigation link"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the error container"

  @spec lens_not_found_error(assigns :: Socket.assigns()) :: Rendered.t()
  def lens_not_found_error(assigns)

  @doc """
  Renders an error message when a vertex cannot be found.
  """
  attr :prefix, :string, required: true, doc: "URL prefix for navigation link"
  attr :lens, Lens, required: true, doc: "Current lens for navigation"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the error container"

  @spec vertex_not_found_error(assigns :: Socket.assigns()) :: Rendered.t()
  def vertex_not_found_error(assigns)

  @doc """
  Renders an error message when the page's data failed to load for any other
  reason; the server log has the details.
  """
  attr :prefix, :string, required: true, doc: "URL prefix for navigation link"
  attr :lens, Lens, required: true, doc: "Current lens for navigation"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the error container"

  @spec data_load_error(assigns :: Socket.assigns()) :: Rendered.t()
  def data_load_error(assigns)

  @doc """
  Renders an error message when content cannot be found for a vertex.
  """
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the error container"

  @spec content_not_found_error(assigns :: Socket.assigns()) :: Rendered.t()
  def content_not_found_error(assigns)

  @doc """
  Renders the content view based on the content type (live component, live view, or static).
  """
  attr :content, Content, doc: "The content to render"
  attr :vertex, :any, required: true, doc: "Current vertex being viewed"
  attr :lens, Lens, required: true, doc: "Current lens for rendering"
  attr :socket, Socket, required: true, doc: "The LiveView socket"
  attr :theme, :atom, required: true, doc: "Current theme (:dark or :light)"
  attr :zoom_graph, :any, required: true, doc: "The zoomed subgraph for visualization"
  attr :graph, :any, default: nil, doc: "Clarity's graph, whose vertices' names text links"
  attr :linking, :list, default: [], doc: "The viewer's text linking options"

  attr :name_style, :atom,
    default: :qualified,
    doc: "How content names modules: `:short` within what holds them, or `:qualified`"

  attr :zoom_level, :any, required: true, doc: "Zoom level tuple {outgoing, incoming}"
  attr :shown_vertex_types, :list, required: true, doc: "List of vertex types currently shown"
  attr :available_vertex_types, :list, required: true, doc: "List of all available vertex types"
  attr :prefix, :string, required: true, doc: "URL prefix for links"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the content container"

  @spec render_content(assigns :: Socket.assigns()) :: Rendered.t()
  def render_content(assigns)

  @doc """
  Renders a vertex name.
  """
  attr :vertex, :any, required: true, doc: "The vertex to display"

  attr :name_style, :atom,
    default: :qualified,
    doc: "Display style for module-named vertices (:qualified or :short)"

  attr :name, :string,
    default: nil,
    doc: "The name to show instead, e.g. one told apart from its siblings' names"

  attr :class, :any, default: nil, doc: "CSS classes to apply to the name"

  @spec vertex_name(assigns :: Socket.assigns()) :: Rendered.t()
  def vertex_name(assigns)

  @doc """
  Renders a drawer for displaying raw content (mermaid, viz, markdown).
  """
  attr :show, :boolean, required: true, doc: "Whether the drawer is visible"
  attr :content_type, :string, required: true, doc: "The type of content (mermaid, viz, markdown)"
  attr :raw_content, :string, required: true, doc: "The raw content to display"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec raw_content_drawer(assigns :: Socket.assigns()) :: Rendered.t()
  def raw_content_drawer(assigns)
end
