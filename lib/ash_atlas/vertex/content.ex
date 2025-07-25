defmodule AshAtlas.Vertex.Content do
  @moduledoc false
  @type content_mermaid() :: {:mermaid, iodata() | (-> iodata())}
  @type content_markdown() :: {:markdown, iodata() | (-> iodata())}
  @type content_viz() :: {:viz, iodata() | (-> iodata())}
  @type content_live_view() :: {:live_view, {module(), session :: map()}}
  @type content() ::
          content_mermaid()
          | content_markdown()
          | content_viz()
          | content_live_view()

  @type t() :: %__MODULE__{
          id: iodata(),
          name: String.t(),
          content: content()
        }

  @enforce_keys [:id, :name, :content]
  defstruct [:id, :name, :content]

  defimpl AshAtlas.Vertex do
    @impl AshAtlas.Vertex
    def unique_id(%{id: id}), do: "content:#{id}"

    @impl AshAtlas.Vertex
    def graph_id(%{id: id}), do: id

    @impl AshAtlas.Vertex
    def graph_group(_vertex), do: []

    @impl AshAtlas.Vertex
    def type_label(_vertex), do: inspect(AshAtlas.Vertex.Content)

    @impl AshAtlas.Vertex
    def render_name(%{name: name}), do: name

    @impl AshAtlas.Vertex
    def dot_shape(_vertex), do: "nil"
  end
end
