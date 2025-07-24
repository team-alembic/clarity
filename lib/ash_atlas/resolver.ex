defmodule AshAtlas.Resolver do
  @callback resolve(graph :: :digraph.t()) :: :digraph.t()
  @callback post_process(graph :: :digraph.t()) :: :digraph.t()

  @resolvers [
    AshAtlas.Resolver.Root,
    AshAtlas.Resolver.Application,
    AshAtlas.Resolver.Domain,
    AshAtlas.Resolver.DataLayer,
    AshAtlas.Resolver.Action,
    AshAtlas.Resolver.Field,
    AshAtlas.Resolver.Type,
    AshAtlas.Resolver.Diagram
  ]

  @spec resolve(graph :: :digraph.t()) :: :digraph.t()
  def resolve(graph) do
    graph = Enum.reduce(@resolvers, graph, & &1.resolve(&2))
    @resolvers |> Enum.reverse() |> Enum.reduce(graph, & &1.post_process(&2))
  end
end
