with {:module, Phoenix.Endpoint} <- Code.ensure_loaded(Phoenix.Endpoint) do
  defmodule Clarity.Content.Phoenix.EndpointPipeline do
    @moduledoc """
    D2 diagram showing the plug pipeline of a Phoenix endpoint.

    Plugs are extracted by reading the endpoint source file and matching
    `plug Module` calls. This is best-effort — endpoints assembled at
    runtime or via macros that obscure the call site may not list every
    plug. When the source cannot be read the diagram falls back to a
    single Endpoint -> Router edge.
    """

    @behaviour Clarity.Content

    alias Clarity.Content.D2.Helpers
    alias Clarity.SourceLocation
    alias Clarity.Vertex.Module, as: ModuleVertex
    alias Clarity.Vertex.Phoenix.Endpoint, as: EndpointVertex

    @impl Clarity.Content
    def name, do: "Pipeline"

    @impl Clarity.Content
    def description, do: "Plug pipeline for this endpoint"

    @impl Clarity.Content
    def sort_priority, do: -50

    @impl Clarity.Content
    def applies?(%EndpointVertex{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%EndpointVertex{endpoint: endpoint}, _lens) do
      {:d2, fn _props -> to_d2(endpoint) end}
    end

    @spec to_d2(module()) :: iodata()
    defp to_d2(endpoint) do
      plugs = endpoint_plugs(endpoint)

      nodes = [{"endpoint", Helpers.short_name(endpoint), endpoint} | plugs]

      [
        "direction: down\n",
        Enum.map(nodes, fn {id, label, module} -> plug_node(id, label, module) end),
        chain_edges(nodes)
      ]
    end

    @spec endpoint_plugs(module()) :: [{String.t(), String.t(), module() | nil}]
    defp endpoint_plugs(endpoint) do
      case endpoint |> SourceLocation.from_module() |> SourceLocation.file_path() do
        file when is_binary(file) ->
          file
          |> read_plugs()
          |> Enum.with_index()
          |> Enum.map(fn {plug_module, idx} ->
            {"plug_#{idx}", Helpers.short_name(plug_module), plug_module}
          end)

        _ ->
          []
      end
    end

    @spec read_plugs(String.t()) :: [module()]
    defp read_plugs(file) do
      case File.read(file) do
        {:ok, source} ->
          ~r/^\s*plug\s+([A-Z][A-Za-z0-9_\.]+)/m
          |> Regex.scan(source, capture: :all_but_first)
          |> Enum.flat_map(&safe_concat/1)

        _ ->
          []
      end
    end

    @spec safe_concat([String.t()]) :: [module()]
    defp safe_concat([name]) do
      [Module.safe_concat([name])]
    rescue
      ArgumentError -> []
    end

    @spec plug_node(String.t(), String.t(), module() | nil) :: iodata()
    defp plug_node(id, label, module) do
      link =
        case module && Code.ensure_loaded(module) do
          {:module, mod} -> ["  link: \"", Helpers.vertex_link(ModuleVertex, [mod]), "\"\n"]
          _ -> []
        end

      [
        id,
        ": ",
        Helpers.quoted(label),
        " {\n",
        "  shape: rectangle\n",
        link,
        "}\n"
      ]
    end

    @spec chain_edges([{String.t(), String.t(), module() | nil}]) :: iodata()
    defp chain_edges(nodes) do
      nodes
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [{src, _, _}, {dst, _, _}] -> [src, " -> ", dst, "\n"] end)
    end
  end
end
