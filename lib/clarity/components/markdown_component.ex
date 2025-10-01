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
  defp render_markdown_with_vertex_links(content, prefix, lens) do
    content
    |> IO.iodata_to_binary()
    |> parse_and_transform_markdown(prefix, lens)
    |> Phoenix.HTML.raw()
  end

  @dialyzer {:nowarn_function, parse_and_transform_markdown: 3}
  @spec parse_and_transform_markdown(
          markdown :: String.t(),
          prefix :: String.t(),
          lens :: Lens.t()
        ) :: String.t()
  defp parse_and_transform_markdown(markdown, prefix, lens) do
    case Earmark.Parser.as_ast(markdown) do
      {:ok, ast, _messages} ->
        ast
        |> Earmark.Transform.map_ast(&transform_vertex_links(&1, prefix, lens))
        |> Earmark.Transform.transform()

      {:error, _reason, _messages} ->
        fallback_render(markdown)
    end
  end

  @spec transform_vertex_links(
          ast_node :: Earmark.Parser.ast_node(),
          prefix :: String.t(),
          lens :: Lens.t()
        ) ::
          Earmark.Parser.ast_node()
  defp transform_vertex_links({"a", attrs, content, meta} = node, prefix, lens) do
    case Enum.find(attrs, fn {key, _value} -> key == "href" end) do
      {"href", "vertex://" <> vertex_path} ->
        new_href = build_clarity_path(vertex_path, prefix, lens)

        new_attrs =
          attrs
          |> Enum.reject(fn {key, _value} -> key == "href" end)
          |> Enum.concat([
            {"href", new_href},
            {"data-phx-link", "patch"},
            {"data-phx-link-state", "push"}
          ])

        {"a", new_attrs, content, meta}

      _other ->
        node
    end
  end

  defp transform_vertex_links(node, _prefix, _lens), do: node

  @spec build_clarity_path(
          vertex_path :: String.t(),
          prefix :: String.t(),
          lens :: Lens.t()
        ) :: String.t()
  defp build_clarity_path(vertex_path, prefix, lens) do
    Path.join([prefix, lens.id, vertex_path])
  end

  @spec fallback_render(markdown :: String.t()) :: String.t()
  defp fallback_render(markdown) do
    case Earmark.as_html(markdown) do
      {:ok, html, _messages} -> html
      {:error, reason, _messages} -> "<p>Error rendering markdown: #{reason}</p>"
    end
  end
end
