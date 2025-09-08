defmodule Atlas.Vertex.Phoenix.Router do
  @moduledoc false
  @type t() :: %__MODULE__{router: module()}
  @enforce_keys [:router]
  defstruct [:router]

  defimpl Atlas.Vertex do
    @impl Atlas.Vertex
    def unique_id(%{router: module}), do: "router:#{inspect(module)}"

    @impl Atlas.Vertex
    def graph_id(%{router: module}), do: inspect(module)

    @impl Atlas.Vertex
    def graph_group(_vertex), do: []

    @impl Atlas.Vertex
    def type_label(_vertex), do: inspect(Atlas.Vertex.Phoenix.Router)

    @impl Atlas.Vertex
    def render_name(%{router: module}), do: inspect(module)

    @impl Atlas.Vertex
    def dot_shape(_vertex), do: "foo"

    @impl Atlas.Vertex
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
  end
end
