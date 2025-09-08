defmodule Atlas.Vertex.Phoenix.Endpoint do
  @moduledoc false
  @type t() :: %__MODULE__{endpoint: module()}
  @enforce_keys [:endpoint]
  defstruct [:endpoint]

  defimpl Atlas.Vertex do
    @impl Atlas.Vertex
    def unique_id(%{endpoint: module}), do: "endpoint:#{inspect(module)}"

    @impl Atlas.Vertex
    def graph_id(%{endpoint: module}), do: inspect(module)

    @impl Atlas.Vertex
    def graph_group(_vertex), do: []

    @impl Atlas.Vertex
    def type_label(_vertex), do: inspect(Atlas.Vertex.Phoenix.Endpoint)

    @impl Atlas.Vertex
    def render_name(%{endpoint: module}), do: inspect(module)

    @impl Atlas.Vertex
    def dot_shape(_vertex), do: "foo"

    @impl Atlas.Vertex
    def markdown_overview(%{endpoint: module}),
      do: ["`", inspect(module), "`\n\n", "URL: ", module.url()]
  end
end
