with {:module, Phoenix.Endpoint} <- Code.ensure_loaded(Phoenix.Endpoint) do
  defmodule Clarity.Content.Phoenix.RouterDiagram do
    @moduledoc """
    D2 diagram of a Phoenix router.

    Renders one container per HTTP verb and one node per route inside it.
    Each node is labelled with the path and target plug, and links to the
    associated controller vertex when one exists.
    """

    @behaviour Clarity.Content

    alias Clarity.Content.D2.Helpers
    alias Clarity.Vertex.Module
    alias Clarity.Vertex.Phoenix.Router
    alias Phoenix.Router.Route

    @impl Clarity.Content
    def name, do: "Router Map"

    @impl Clarity.Content
    def description, do: "Visual map of all routes in this router"

    @impl Clarity.Content
    def sort_priority, do: -50

    @impl Clarity.Content
    def applies?(%Router{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Router{router: router}, _lens) do
      {:d2, fn _props -> to_d2(router) end}
    end

    @spec to_d2(module()) :: iodata()
    defp to_d2(router) do
      routes = router.__routes__()

      grouped =
        routes
        |> Enum.group_by(& &1.verb)
        |> Enum.sort_by(fn {verb, _} -> Atom.to_string(verb) end)

      [
        "direction: down\n",
        Enum.map(grouped, &verb_container/1)
      ]
    end

    @spec verb_container({atom(), [Route.t()]}) :: iodata()
    defp verb_container({verb, routes}) do
      verb_id = Helpers.safe_id(Atom.to_string(verb))
      verb_label = verb |> Atom.to_string() |> String.upcase()

      [
        verb_id,
        ": ",
        Helpers.quoted(verb_label),
        " {\n",
        "  shape: package\n",
        routes
        |> Enum.with_index()
        |> Enum.map(fn {route, idx} -> route_node(verb_id, route, idx) end),
        "}\n"
      ]
    end

    @spec route_node(iodata(), Route.t(), non_neg_integer()) :: iodata()
    defp route_node(_verb_id, route, idx) do
      label =
        IO.iodata_to_binary([
          route.path,
          "\n→ ",
          inspect(route.plug),
          action_suffix(route.plug_opts)
        ])

      node_body =
        case Code.ensure_loaded(route.plug) do
          {:module, module} ->
            [
              "    link: \"",
              Helpers.vertex_link(Module, [module]),
              "\"\n"
            ]

          _ ->
            []
        end

      [
        "  route_",
        Integer.to_string(idx),
        ": ",
        Helpers.quoted(label),
        " {\n",
        "    shape: rectangle\n",
        node_body,
        "  }\n"
      ]
    end

    @spec action_suffix(term()) :: String.t()
    defp action_suffix(action) when is_atom(action) and not is_nil(action),
      do: "." <> Atom.to_string(action)

    defp action_suffix(_), do: ""
  end
end
