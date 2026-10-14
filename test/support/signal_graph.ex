defmodule Clarity.Test.SignalGraph do
  @moduledoc false

  alias Ash.Signals.Info
  alias Clarity.Graph
  alias Clarity.Introspector.Ash.Signal, as: SignalIntrospector
  alias Clarity.Vertex.Ash.Action
  alias Clarity.Vertex.Ash.Signal
  alias Clarity.Vertex.Ash.SignalModule
  alias Clarity.Vertex.Root

  @signal_modules [Demo.Billing.Signals, Demo.Signals]
  @resources [
    Demo.Billing.Invoice,
    Demo.Billing.Subscription,
    Demo.Accounts.AuditEvent,
    Demo.Helpdesk.CustomerContact
  ]

  @doc "Returns a graph of the demo's signals, with the edges that the signal introspector adds."
  @spec build() :: Graph.t()
  def build do
    graph = Graph.new()
    root = %Root{}

    for module <- @signal_modules do
      module_vertex = %SignalModule{signal_module: module}
      Graph.add_vertex(graph, module_vertex, root)

      for signal <- Info.signals(module) do
        signal_vertex = %Signal{signal_module: module, signal: signal}
        Graph.add_vertex(graph, signal_vertex, module_vertex)
        Graph.add_edge(graph, module_vertex, signal_vertex, :signal)
      end
    end

    for resource <- @resources, action <- Ash.Resource.Info.actions(resource) do
      action_vertex = %Action{action: action, resource: resource}
      Graph.add_vertex(graph, action_vertex, root)
      {:ok, entries} = SignalIntrospector.introspect_vertex(action_vertex, graph)
      for {:edge, from, to, label} <- entries, do: Graph.add_edge(graph, from, to, label)
    end

    graph
  end

  @doc "Returns the vertex of a signal."
  @spec signal(module(), atom()) :: Signal.t()
  def signal(module, name), do: %Signal{signal_module: module, signal: Info.signal(module, name)}

  @doc "Returns the vertex of an action."
  @spec action(module(), atom()) :: Action.t()
  def action(resource, name),
    do: %Action{action: Ash.Resource.Info.action(resource, name), resource: resource}
end
