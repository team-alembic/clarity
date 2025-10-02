with {:module, Phoenix.Endpoint} <- Code.ensure_loaded(Phoenix.Endpoint) do
  defmodule Clarity.Content.Phoenix.RouterRoutes do
    @moduledoc """
    Content provider for Phoenix Router routes.

    Displays all routes defined in a Phoenix router in a table format.
    """

    @behaviour Clarity.Content

    alias Clarity.Vertex.Phoenix.Router

    @impl Clarity.Content
    def name, do: "Routes"

    @impl Clarity.Content
    def description, do: "All routes defined in this router"

    @impl Clarity.Content
    def applies?(%Router{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Router{router: router_module}, _lens) do
      {:markdown, fn _props -> generate_routes_table(router_module) end}
    end

    @spec generate_routes_table(module()) :: iodata()
    defp generate_routes_table(router_module) do
      routes = router_module.__routes__()

      [
        "| Name | Method | Path | Plug | Action |\n",
        "| ---- | ------ | ---- | ---- | ------ |\n",
        Enum.map(routes, &route_row/1)
      ]
    end

    @spec route_row(Phoenix.Router.Route.t()) :: iodata()
    defp route_row(route) do
      helper_name =
        case Map.fetch(route, :helper) do
          :error -> ""
          {:ok, nil} -> ""
          {:ok, helper} -> [helper, "_path"]
        end

      [
        "| ",
        helper_name,
        " | ",
        route.verb |> Atom.to_string() |> String.upcase(),
        " | ",
        route.path,
        " | ",
        inspect(route.plug),
        " | ",
        inspect(route.plug_opts),
        " |\n"
      ]
    end
  end
end
