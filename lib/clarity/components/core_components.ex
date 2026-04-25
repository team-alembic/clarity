defmodule Clarity.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  import Clarity.Components.MarkdownComponent
  import Clarity.IconComponents
  import Phoenix.HTML

  alias Clarity.Content
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  embed_templates "core_components/*"

  attr :socket, Socket, required: true, doc: "The LiveView socket"
  attr :prefix, :string, default: "/", doc: "The URL prefix for links"

  attr :lens, Lens,
    required: true,
    doc: "Current lens for perspective switching"

  attr :theme, :atom, required: true, doc: "Current theme (:dark or :light)"
  attr :engine, :string, required: true, doc: "Current Graphviz layout engine id"
  attr :clarity_pid, :any, required: true, doc: "PID of the Clarity server process"
  attr :class, :string, default: "", doc: "CSS classes to apply to the header container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the header container"

  @spec header(assigns :: Socket.assigns()) :: Rendered.t()
  def header(assigns)

  attr :id, :string, required: true, doc: "The unique ID for the visualization element"
  attr :graph, :string, required: true, doc: "The graph data in DOT language format"

  attr :engine, :string,
    default: "dot",
    doc: "Graphviz layout engine: dot, neato, fdp, sfdp, circo, twopi, osage"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the graph container"

  @spec viz(assigns :: Socket.assigns()) :: Rendered.t()
  def viz(assigns)

  attr :id, :string, required: true, doc: "The unique ID for the mermaid visualization"
  attr :graph, :string, required: true, doc: "The mermaid graph definition in string format"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the graph container"

  @spec mermaid(assigns :: Socket.assigns()) :: Rendered.t()
  def mermaid(assigns)

  attr :id, :string, required: true, doc: "The unique ID for the theme toggle button"
  attr :theme, :atom, required: true, doc: "Current theme (:dark or :light)"
  attr :class, :string, default: "", doc: "CSS classes to apply to the theme toggle button"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the theme toggle button"

  @spec theme_toggle(assigns :: Socket.assigns()) :: Rendered.t()
  def theme_toggle(assigns)

  attr :flash, :map, default: %{}, doc: "The flash messages to display"
  attr :class, :string, default: "", doc: "CSS classes to apply to the flash container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  @spec flash_group(assigns :: Socket.assigns()) :: Rendered.t()
  def flash_group(assigns)

  attr :class, :string, default: "", doc: "CSS classes to apply to the loading spinner container"

  attr :rest, :global,
    doc: "the arbitrary HTML attributes to add to the loading spinner container"

  @spec loading_spinner(assigns :: Socket.assigns()) :: Rendered.t()
  def loading_spinner(assigns)

  @doc """
  Renders the Clarity splash screen with animated logo.
  """
  attr :class, :string, default: nil
  attr :rest, :global

  @spec splash_screen(map()) :: Rendered.t()
  def splash_screen(assigns)

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

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the tabs container"

  @spec tabs(assigns :: Socket.assigns()) :: Rendered.t()
  def tabs(assigns)

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
  attr :engine, :string, required: true, doc: "Current Graphviz layout engine id"
  attr :zoom_graph, :any, required: true, doc: "The zoomed subgraph for visualization"
  attr :zoom_level, :any, required: true, doc: "Zoom level tuple {outgoing, incoming}"
  attr :shown_vertex_types, :list, required: true, doc: "List of vertex types currently shown"
  attr :available_vertex_types, :list, required: true, doc: "List of all available vertex types"
  attr :prefix, :string, required: true, doc: "URL prefix for links"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the content container"

  @spec render_content(assigns :: Socket.assigns()) :: Rendered.t()
  def render_content(assigns)

  @doc """
  Renders a vertex name with tooltip data attribute.
  """
  attr :vertex, :any, required: true, doc: "The vertex to display"

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
