defmodule AshAtlas.Vertex.Content do
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
    def unique_id(%{id: id}), do: "content:#{id}"
    def graph_id(%{id: id}), do: id
    def graph_group(_vertex), do: []
    def type_label(_vertex), do: inspect(AshAtlas.Vertex.Content)
    def render_name(%{name: name}), do: name
    def dot_shape(_vertex), do: "nil"
  end
end
