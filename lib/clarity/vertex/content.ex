defmodule Clarity.Vertex.Content do
  @moduledoc false

  @type viz_options() :: %{theme: :dark | :light}
  @type content_mermaid() :: {:mermaid, iodata() | (-> iodata())}
  @type content_markdown() :: {:markdown, iodata() | (-> iodata())}
  @type content_viz() :: {:viz, iodata() | (viz_options() -> iodata())}
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

  defimpl Clarity.Vertex do
    @impl Clarity.Vertex
    def unique_id(%{id: id}), do: "content:#{id}"

    @impl Clarity.Vertex
    def graph_id(%{id: id}), do: id

    @impl Clarity.Vertex
    def graph_group(_vertex), do: []

    @impl Clarity.Vertex
    def type_label(_vertex), do: inspect(Clarity.Vertex.Content)

    @impl Clarity.Vertex
    def render_name(%{name: name}), do: name

    @impl Clarity.Vertex
    def dot_shape(_vertex), do: "nil"

    @impl Clarity.Vertex
    def markdown_overview(_vertex), do: []

    @impl Clarity.Vertex
    def source_location(_vertex), do: nil
  end
end
