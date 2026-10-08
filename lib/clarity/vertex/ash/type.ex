with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Type do
    @moduledoc """
    Vertex implementation for Ash types.
    """

    alias Clarity.SourceLocation
    alias Clarity.Vertex.HintProvider

    @type t() :: %__MODULE__{
            type: Ash.Type.t()
          }
    @enforce_keys [:type]
    defstruct [:type]

    @short_names Map.new(Ash.Type.short_names(), fn {short, module} -> {module, short} end)

    @doc """
    Returns a type's name as Ash's DSL writes it: `string` for
    `Ash.Type.String`, `list of uuid` for an array of `Ash.Type.UUID`.

    ## Examples

        iex> Clarity.Vertex.Ash.Type.short_name({:array, Ash.Type.UUID})
        "list of uuid"

    """
    @spec short_name(term()) :: String.t()
    def short_name({:array, inner}), do: "list of " <> short_name(inner)

    def short_name(type) when is_map_key(@short_names, type),
      do: Atom.to_string(Map.fetch!(@short_names, type))

    def short_name(type) when is_atom(type),
      do: type |> inspect() |> String.replace_prefix("Ash.Type.", "")

    def short_name(type), do: inspect(type)

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{type: type}), do: Util.id(@for, [type])

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Ash.Type)

      @impl Clarity.Vertex
      def name(%@for{type: type}), do: inspect(type)
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "plain"
    end

    defimpl Clarity.Vertex.ModuleProvider do
      @impl Clarity.Vertex.ModuleProvider
      def module(%@for{type: type}), do: type
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%@for{type: module}) do
        SourceLocation.from_module(module)
      end
    end

    defimpl Clarity.Vertex.TooltipProvider do
      @impl Clarity.Vertex.TooltipProvider
      def tooltip(vertex) do
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

      @spec truncate_markdown(content :: String.t(), length :: pos_integer()) :: String.t()
      defp truncate_markdown(content, length \\ 10) do
        content
        |> String.split("\n")
        |> Enum.take(length)
        |> then(fn lines -> if length(lines) == length, do: lines ++ ["..."], else: lines end)
        |> Enum.join("\n")
      end
    end

    defimpl Clarity.Vertex.HintProvider do
      @impl HintProvider
      def icon(_vertex), do: :type

      @impl HintProvider
      def badges(_vertex), do: []

      @impl HintProvider
      def facts(_vertex), do: []
    end
  end
end
