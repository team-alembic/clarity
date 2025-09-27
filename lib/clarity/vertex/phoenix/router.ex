defmodule Clarity.Vertex.Phoenix.Router do
  @moduledoc false
  @type t() :: %__MODULE__{router: module()}
  @enforce_keys [:router]
  defstruct [:router]

  defimpl Clarity.Vertex do
    @impl Clarity.Vertex
    def unique_id(%{router: module}), do: "router:#{inspect(module)}"

    @impl Clarity.Vertex
    def graph_id(%{router: module}), do: inspect(module)

    @impl Clarity.Vertex
    def graph_group(_vertex), do: []

    @impl Clarity.Vertex
    def type_label(_vertex), do: "Clarity.Vertex.Phoenix.Router"

    @impl Clarity.Vertex
    def render_name(%{router: module}), do: inspect(module)

    @impl Clarity.Vertex
    def dot_shape(_vertex), do: "foo"

    @impl Clarity.Vertex
    def markdown_overview(%{router: module}),
      do: [
        "`",
        inspect(module),
        "`\n\n",
        "| Name | Method | Path | Plug | Action |\n",
        "| ---- | ------ | ---- | ---------- | ------ |\n",
        Enum.map(module.__routes__(), fn %{
                                           verb: verb,
                                           path: path,
                                           plug: plug,
                                           plug_opts: plug_opts
                                         } = route ->
          [
            "| ",
            case Map.fetch(route, :helper) do
              :error -> ""
              {:ok, nil} -> ""
              {:ok, helper} -> [helper, "_path"]
            end,
            " | ",
            verb |> Atom.to_string() |> String.upcase(),
            " | ",
            path,
            " | ",
            inspect(plug),
            " | ",
            inspect(plug_opts),
            " |\n"
          ]
        end)
      ]

    @impl Clarity.Vertex
    def source_anno(%{router: module}) do
      case module.__info__(:compile)[:source] do
        source when is_list(source) ->
          :erl_anno.set_file(source, :erl_anno.new(1))

        _ ->
          nil
      end
    rescue
      _ ->
        nil
    end
  end
end
