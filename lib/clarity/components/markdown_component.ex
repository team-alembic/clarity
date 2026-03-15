defmodule Clarity.Components.MarkdownComponent do
  @moduledoc """
  Phoenix component for rendering markdown content with vertex:// link transformation.

  This component parses markdown content and transforms vertex:// links into proper
  application routes, enabling navigation within the Clarity interface.
  """

  use Phoenix.Component

  alias Clarity.Components.CodeHighlighter
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
        |> Earmark.Transform.map_ast(&transform_code_blocks/1)
        |> transform_inline_code_in_ast()
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

  @spec transform_code_blocks(ast_node :: Earmark.Parser.ast_node()) ::
          Earmark.Parser.ast_node() | {:replace, Earmark.Parser.ast_node()}
  defp transform_code_blocks(
         {"pre", pre_attrs, [{"code", code_attrs, [content], code_meta}], pre_meta} = node
       ) do
    language = extract_language(code_attrs)

    case CodeHighlighter.get_lexer(language) do
      nil ->
        node

      lexer ->
        highlighted_spans = Makeup.highlight_inner_html(content, lexer: lexer)
        code_meta_with_verbatim = Map.put(code_meta, :verbatim, true)
        pre_meta_with_verbatim = Map.put(pre_meta, :verbatim, true)

        new_node =
          {"pre", [{"class", "highlight"} | pre_attrs],
           [{"code", code_attrs, [highlighted_spans], code_meta_with_verbatim}],
           pre_meta_with_verbatim}

        {:replace, new_node}
    end
  end

  defp transform_code_blocks(node), do: node

  @spec transform_inline_code_in_ast(ast :: list()) :: list()
  defp transform_inline_code_in_ast(ast) when is_list(ast) do
    Enum.map(ast, &transform_inline_code_node/1)
  end

  @spec transform_inline_code_node(node :: Earmark.Parser.ast_node() | binary()) ::
          Earmark.Parser.ast_node() | binary()
  defp transform_inline_code_node({"pre", _, _, _} = node), do: node

  defp transform_inline_code_node({"code", _attrs, content, meta}) do
    {"strong", [{"class", "font-mono"}], content, meta}
  end

  defp transform_inline_code_node({tag, attrs, children, meta}) do
    {tag, attrs, transform_inline_code_in_ast(children), meta}
  end

  defp transform_inline_code_node(other), do: other

  @spec extract_language(attrs :: list()) :: String.t() | nil
  defp extract_language(attrs) do
    case Enum.find(attrs, fn {key, _value} -> key == "class" end) do
      {"class", class_value} ->
        class_value
        |> String.split()
        |> Enum.find(&(&1 not in ["", "inline"]))

      _other ->
        nil
    end
  end

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
