defmodule Clarity.Components.MarkdownComponent do
  @moduledoc """
  Phoenix component for rendering markdown content with vertex:// link transformation.

  This component parses markdown content and transforms vertex:// links into proper
  application routes, enabling navigation within the Clarity interface. Given
  Clarity's `graph`, it also links the names of vertices the text mentions (see
  `Clarity.Autolink`), settling ambiguous names by the `vertex` the text is about,
  each in the lens if its tree shows it, else in the default lens.
  """

  use Phoenix.Component

  alias Clarity.Autolink
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker
  alias Clarity.Vertex
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  require Logger

  # What links names in the text, and how: see `Clarity.Autolink`.
  @typep naming() :: %{
           graph: Clarity.Graph.t() | nil,
           vertex: Vertex.t() | nil,
           lowercase: boolean()
         }

  @extension_opts [extension: [table: true, strikethrough: true]]
  @highlight_opts [syntax_highlight: [formatter: {:html_linked, pre_class: "highlight"}]]

  attr :content, :any, required: true, doc: "The markdown content to render"
  attr :prefix, :string, required: true, doc: "URL prefix for link generation"
  attr :lens, Lens, required: true, doc: "Current lens for link generation"
  attr :graph, :any, default: nil, doc: "The graph whose vertices' names to link; nil links none"
  attr :vertex, :any, default: nil, doc: "The vertex the text is about, if any"

  attr :link_lowercase, :boolean,
    default: false,
    doc: "Whether to link lowercase mentions too, as `Clarity.Autolink.link/4` does"

  attr :class, :string, default: "", doc: "CSS classes to apply to the markdown container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the markdown container"

  @spec markdown(assigns :: Socket.assigns()) :: Rendered.t()
  def markdown(assigns) do
    ~H"""
    <div class={"prose dark:prose-invert #{@class}"} {@rest}>
      {render_markdown_with_vertex_links(@content, @prefix, @lens, %{
        graph: @graph,
        vertex: @vertex,
        lowercase: @link_lowercase
      })}
    </div>
    """
  end

  @spec render_markdown_with_vertex_links(
          content :: String.t() | iodata(),
          prefix :: String.t(),
          lens :: Lens.t(),
          naming :: naming()
        ) ::
          Phoenix.HTML.safe()
  # HTML is produced and escaped by MDEx; prefix/lens are path-safe values, not user HTML.
  # sobelow_skip ["XSS.Raw"]
  defp render_markdown_with_vertex_links(content, prefix, lens, naming) do
    content
    |> parse_and_transform_markdown(prefix, lens, naming)
    |> Phoenix.HTML.raw()
  end

  # iodata_to_binary lives inside the rescue so malformed/nil content (e.g. a
  # third-party content provider returning non-iodata) degrades gracefully
  # instead of crashing the surrounding render.
  @spec parse_and_transform_markdown(
          content :: String.t() | iodata(),
          prefix :: String.t(),
          lens :: Lens.t(),
          naming :: naming()
        ) :: String.t()
  defp parse_and_transform_markdown(content, prefix, lens, naming) do
    highlight_opts = highlight_opts()

    content
    |> IO.iodata_to_binary()
    |> MDEx.parse_document!(@extension_opts ++ highlight_opts)
    # Before vertex:// links become raw HTML, while they're still links to skip.
    |> link_names(naming, prefix, lens)
    |> MDEx.traverse_and_update(&transform_vertex_links(&1, prefix, lens))
    |> MDEx.to_html!(highlight_opts)
  rescue
    exception ->
      Logger.error("Clarity: couldn't render markdown: " <> Exception.message(exception))
      "<p>Error rendering markdown</p>"
  end

  # MDEx (>= 0.13) only highlights when `mdex_native` was compiled with Lumis,
  # which is selected by the consuming app's compile-time config — a library
  # cannot set it on their behalf. Without it, requesting the Lumis formatter
  # raises, so we render unhighlighted instead and nudge towards the upgrade.
  @spec highlight_opts() :: keyword()
  defp highlight_opts do
    if Application.get_env(:mdex_native, :syntax_highlighter) == :lumis do
      @highlight_opts
    else
      warn_syntax_highlighting_disabled()
      []
    end
  end

  @spec warn_syntax_highlighting_disabled() :: :ok
  defp warn_syntax_highlighting_disabled do
    if :persistent_term.get({__MODULE__, :highlight_warning}, false) do
      :ok
    else
      :persistent_term.put({__MODULE__, :highlight_warning}, true)

      Logger.warning("""
      Clarity: code blocks will render without syntax highlighting because \
      `mdex_native` was compiled without Lumis support.

      Run `mix igniter.upgrade clarity` to add the required configuration, or \
      add it manually and recompile:

          config :mdex_native, syntax_highlighter: :lumis
      """)
    end
  end

  @spec link_names(MDEx.Document.t(), naming(), String.t(), Lens.t()) :: MDEx.Document.t()
  defp link_names(document, %{graph: nil}, _prefix, _lens), do: document

  defp link_names(document, %{graph: graph, vertex: vertex, lowercase: lowercase}, prefix, lens) do
    default_lens = default_lens()

    Autolink.link(
      document,
      Autolink.names(graph, vertex, lowercase: lowercase),
      &build_clarity_path(Vertex.id(&1), prefix, link_lens(&1, lens, default_lens)),
      lowercase: lowercase,
      vertex: vertex
    )
  end

  # The lens a named vertex opens in: this one if its tree shows vertices of
  # the kind, or else the default lens, so a field named in the Documentation
  # lens, whose tree has no fields, opens where it has tabs.
  @spec link_lens(Vertex.t(), Lens.t(), Lens.t() | nil) :: Lens.t()
  defp link_lens(%type{}, lens, default_lens) do
    cond do
      shows?(lens, type) -> lens
      default_lens != nil and shows?(default_lens, type) -> default_lens
      true -> lens
    end
  end

  @spec shows?(Lens.t(), module()) :: boolean()
  defp shows?(lens, type), do: type in lens.show_vertex_types.([type])

  @spec default_lens() :: Lens.t() | nil
  defp default_lens do
    case Lensmaker.get_lens_by_id(Clarity.Config.fetch_default_perspective_lens!()) do
      {:ok, lens} -> lens
      {:error, :lens_not_found} -> nil
    end
  end

  @spec transform_vertex_links(MDEx.Document.md_node(), String.t(), Lens.t()) ::
          MDEx.Document.md_node()
  defp transform_vertex_links(%{nodes: children} = parent, prefix, lens) when is_list(children) do
    if Enum.any?(children, &vertex_link?/1) do
      %{parent | nodes: rewrite_vertex_links(children, prefix, lens)}
    else
      parent
    end
  end

  defp transform_vertex_links(node, _prefix, _lens), do: node

  @spec vertex_link?(node :: MDEx.Document.md_node()) :: boolean()
  defp vertex_link?(%MDEx.Link{url: "vertex://" <> _}), do: true
  defp vertex_link?(_), do: false

  @spec rewrite_vertex_links([MDEx.Document.md_node()], String.t(), Lens.t()) ::
          [MDEx.Document.md_node()]
  defp rewrite_vertex_links(children, prefix, lens) do
    Enum.flat_map(children, fn
      %MDEx.Link{url: "vertex://" <> vertex_path, nodes: link_children, title: title} ->
        vertex_path
        |> build_clarity_path(prefix, lens)
        |> Autolink.patch_link(link_children, title)

      other ->
        [other]
    end)
  end

  @spec build_clarity_path(
          vertex_path :: String.t(),
          prefix :: String.t(),
          lens :: Lens.t()
        ) :: String.t()
  defp build_clarity_path(vertex_path, prefix, lens) do
    Path.join([prefix, lens.id, vertex_path])
  end
end
