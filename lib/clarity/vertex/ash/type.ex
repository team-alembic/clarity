with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Type do
    @moduledoc false

    alias Clarity.SourceLocation

    @type t() :: %__MODULE__{
            type: Ash.Type.t()
          }
    @enforce_keys [:type]
    defstruct [:type]

    defimpl Clarity.Vertex do
      @impl Clarity.Vertex
      def unique_id(%{type: type}), do: "type:#{inspect(type)}"

      @impl Clarity.Vertex
      def graph_id(%{type: type}), do: inspect(type)

      @impl Clarity.Vertex
      def graph_group(_vertex), do: []

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Ash.Type)

      @impl Clarity.Vertex
      def render_name(%{type: type}), do: inspect(type)

      @impl Clarity.Vertex
      def dot_shape(_vertex), do: "plain"

      @impl Clarity.Vertex
      def markdown_overview(vertex) do
        [
          "`",
          inspect(vertex.type),
          "`\n\n",
          case Code.fetch_docs(vertex.type) do
            {:docs_v1, _annotation, _beam_language, "text/markdown", %{"en" => moduledoc},
             _metadata, _docs} ->
              truncate_markdown(moduledoc)

            _ ->
              []
          end
        ]
      end

      @impl Clarity.Vertex
      def source_location(%{type: module}) do
        SourceLocation.from_module(module)
      end

      @spec truncate_markdown(content :: String.t(), length :: pos_integer()) :: String.t()
      defp truncate_markdown(content, length \\ 10) do
        content
        |> String.split("\n")
        |> Enum.take(length)
        |> then(fn lines -> if length(lines) == length, do: lines ++ ["..."], else: lines end)
        |> Enum.join("\n")
      end
    end
  end
end
