defmodule Clarity.Introspector.Parent do
  @moduledoc false

  alias Clarity.Config
  alias Clarity.Graph
  alias Clarity.Vertex
  alias Clarity.Vertex.Util

  @doc "Returns the vertex of the module's domain or, without a domain, of its application."
  @spec vertex(module(), module() | nil, Graph.t()) ::
          {:ok, Vertex.t() | nil} | {:error, {:unmet_dependencies, [module()]}}
  def vertex(module, nil, graph) do
    app = Config.application_of(module)
    {:ok, Graph.get_vertex(graph, Util.id(Vertex.Application, [app]))}
  end

  def vertex(_module, domain, graph) do
    case Graph.get_vertex(graph, Util.id(Vertex.Ash.Domain, [domain])) do
      nil -> {:error, {:unmet_dependencies, [domain]}}
      domain_vertex -> {:ok, domain_vertex}
    end
  end
end
