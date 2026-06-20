defmodule Clarity.Components.MarkdownComponent do
  @moduledoc """
  Phoenix component for rendering markdown content with vertex:// link transformation.

  This component parses markdown content and transforms vertex:// links into proper
  application routes, enabling navigation within the Clarity interface.
  """

  use Phoenix.Component

  alias Clarity.Perspective.Lens
  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  @mdex_opts [
    extension: [table: true, strikethrough: true],
    syntax_highlight: [formatter: {:html_linked, pre_class: "highlight"}]
  ]

  attr :content, :any, required: true, doc: "The markdown content to render"
  attr :prefix, :string, required: true, doc: "URL prefix for link generation"
  attr :lens, Lens, required: true, doc: "Current lens for link generation"
  attr :class, :string, default: "", doc: "CSS classes to apply to the markdown container"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the markdown container"

  @spec markdown(assigns :: Socket.assigns()) :: Rendered.t()
  def markdown(assigns) do
    ~H"""
    <div class={"prose dark:prose-invert #{@class}"} {@rest}>
      {render_markdown_with_vertex_links(@content, @prefix, @lens)}
    </div>
    """
  end

  @spec render_markdown_with_vertex_links(
          content :: String.t() | iodata(),
          prefix :: String.t(),
          lens :: Lens.t()
        ) ::
          Phoenix.HTML.safe()
  # HTML is produced and escaped by MDEx; prefix/lens are path-safe values, not user HTML.
  # sobelow_skip ["XSS.Raw"]
  defp render_markdown_with_vertex_links(content, prefix, lens) do
    content
    |> parse_and_transform_markdown(prefix, lens)
    |> Phoenix.HTML.raw()
  end

  # iodata_to_binary lives inside the rescue so malformed/nil content (e.g. a
  # third-party content provider returning non-iodata) degrades gracefully
  # instead of crashing the surrounding render.
  @spec parse_and_transform_markdown(
          content :: String.t() | iodata(),
          prefix :: String.t(),
          lens :: Lens.t()
        ) :: String.t()
  defp parse_and_transform_markdown(content, prefix, lens) do
    content
    |> IO.iodata_to_binary()
    |> MDEx.parse_document!(@mdex_opts)
    |> MDEx.traverse_and_update(&transform_vertex_links(&1, prefix, lens))
    |> MDEx.to_html!(syntax_highlight: @mdex_opts[:syntax_highlight])
  rescue
    _exception -> "<p>Error rendering markdown</p>"
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

  # MDEx.Link has no HTML attributes field; use Raw nodes for data-phx-link attrs.
  @spec rewrite_vertex_links([MDEx.Document.md_node()], String.t(), Lens.t()) ::
          [MDEx.Document.md_node()]
  defp rewrite_vertex_links(children, prefix, lens) do
    Enum.flat_map(children, fn
      %MDEx.Link{url: "vertex://" <> vertex_path, nodes: link_children, title: title} ->
        vertex_path
        |> build_clarity_path(prefix, lens)
        |> raw_phx_link(link_children, title)

      other ->
        [other]
    end)
  end

  @spec raw_phx_link(
          url :: String.t(),
          children :: [MDEx.Document.md_node()],
          title :: String.t() | nil
        ) :: [MDEx.Document.md_node()]
  defp raw_phx_link(url, children, title) do
    title_attr = if title in [nil, ""], do: "", else: ~s( title="#{escape(title)}")

    open = %MDEx.Raw{
      literal:
        ~s(<a href="#{escape(url)}" data-phx-link="patch" data-phx-link-state="push"#{title_attr}>)
    }

    close = %MDEx.Raw{literal: "</a>"}
    [open | children] ++ [close]
  end

  # Escape untrusted values before splicing into Raw HTML literals.
  @spec escape(value :: String.t()) :: String.t()
  defp escape(value), do: value |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  @spec build_clarity_path(
          vertex_path :: String.t(),
          prefix :: String.t(),
          lens :: Lens.t()
        ) :: String.t()
  defp build_clarity_path(vertex_path, prefix, lens) do
    Path.join([prefix, lens.id, vertex_path])
  end
end
