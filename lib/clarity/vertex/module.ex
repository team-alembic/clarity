defmodule Clarity.Vertex.Module do
  @moduledoc false

  alias Clarity.SourceLocation

  @type t() :: %__MODULE__{
          module: module(),
          version: :unknown | String.t()
        }
  @enforce_keys [:module]
  defstruct [:module, version: :unknown]

  defimpl Clarity.Vertex do
    @impl Clarity.Vertex
    def unique_id(%{module: module, version: version}) do
      version_str =
        case version do
          :unknown -> "unknown"
          v -> to_string(v)
        end

      "module:#{inspect(module)}:#{version_str}"
    end

    @impl Clarity.Vertex
    def graph_id(%{module: module}), do: inspect(module)

    @impl Clarity.Vertex
    def graph_group(_vertex), do: []

    @impl Clarity.Vertex
    def type_label(_vertex), do: inspect(Module)

    @impl Clarity.Vertex
    def render_name(%{module: module}), do: inspect(module)

    @impl Clarity.Vertex
    def dot_shape(_vertex), do: "box"

    @impl Clarity.Vertex
    def markdown_overview(%{module: module}) do
      [
        "`",
        inspect(module),
        "`",
        case Code.fetch_docs(module) do
          {:docs_v1, _annotation, _beam_language, "text/markdown", %{"en" => moduledoc},
           _metadata, _docs} ->
            ["\n\n", moduledoc]

          _ ->
            []
        end
      ]
    end

    @impl Clarity.Vertex
    def source_location(%{module: module}) do
      SourceLocation.from_module(module)
    end
  end
end
