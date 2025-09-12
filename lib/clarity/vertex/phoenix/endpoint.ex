defmodule Clarity.Vertex.Phoenix.Endpoint do
  @moduledoc false
  @type t() :: %__MODULE__{endpoint: module()}
  @enforce_keys [:endpoint]
  defstruct [:endpoint]

  defimpl Clarity.Vertex do
    @impl Clarity.Vertex
    def unique_id(%{endpoint: module}), do: "endpoint:#{inspect(module)}"

    @impl Clarity.Vertex
    def graph_id(%{endpoint: module}), do: inspect(module)

    @impl Clarity.Vertex
    def graph_group(_vertex), do: []

    @impl Clarity.Vertex
    def type_label(_vertex), do: inspect(Clarity.Vertex.Phoenix.Endpoint)

    @impl Clarity.Vertex
    def render_name(%{endpoint: module}), do: inspect(module)

    @impl Clarity.Vertex
    def dot_shape(_vertex), do: "foo"

    @impl Clarity.Vertex
    def markdown_overview(%{endpoint: module}),
      do: ["`", inspect(module), "`\n\n", "URL: ", module.url()]
  end
end
