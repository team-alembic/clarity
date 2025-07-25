defmodule AshAtlas.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  import Phoenix.HTML

  alias AshAtlas.Vertex

  attr(:vertex, :any, required: true, doc: "The vertex to render")

  def vertex_name(assigns) do
    ~H"""
    {Vertex.render_name(@vertex)}
    """
  end

  attr(:id, :string, required: true, doc: "The unique ID for the visualization element")
  attr(:graph, :string, required: true, doc: "The graph data in DOT language format")
  attr(:rest, :global, doc: "the arbitrary HTML attributes to add to the flash container")

  def viz(assigns) do
    ~H"""
    <pre phx-hook="Viz" id={@id} data-graph={@graph} phx-update="ignore" {@rest}></pre>
    """
  end

  attr(:id, :string, required: true, doc: "The unique ID for the mermaid visualization")
  attr(:graph, :string, required: true, doc: "The mermaid graph definition in string format")
  attr(:rest, :global, doc: "the arbitrary HTML attributes to add to the flash container")

  def mermaid(assigns) do
    ~H"""
    <pre phx-hook="Mermaid" id={@id} data-graph={@graph} phx-update="ignore" {@rest}></pre>
    """
  end

  attr(:content, :string, required: true, doc: "The markdown content to render")
  attr(:class, :string, default: "", doc: "CSS classes to apply to the markdown container")
  attr(:rest, :global, doc: "the arbitrary HTML attributes to add to the flash container")

  def markdown(assigns) do
    ~H"""
    <div class={"prose prose-invert #{@class}"} {@rest}>
      <%= case Earmark.as_html(@content) do
        {:ok, html, _} -> raw(html)
        {:error, reason, _} -> "<p>Error rendering markdown: #{reason}</p>"
      end %>
    </div>
    """
  end
end
