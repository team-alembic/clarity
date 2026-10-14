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

  @doc "Compiles a resource whose emit and listener name a signal that does not exist."
  @spec compile_broken(module(), module()) :: module()
  def compile_broken(domain, resource) do
    compile_resource(domain, resource, """
    signals_in do
      from Demo.Billing.Signals do
        on :no_such_signal, :react
      end
    end

    actions do
      defaults [:read]

      update :touch do
        accept []
        emit Demo.Billing.Signals, :no_such_signal
      end

      action :react do
        argument :signal, :struct, allow_nil?: false
        run fn _input, _context -> :ok end
      end
    end
    """)
  end

  @doc "Compiles a resource with a listener whose action does not exist."
  @spec compile_listener_without_action(module(), module()) :: module()
  def compile_listener_without_action(domain, resource) do
    compile_resource(domain, resource, """
    signals_in do
      from Demo.Billing.Signals do
        on :invoice_paid, :thank_you
      end
    end

    actions do
      defaults [:read]
    end
    """)
  end

  @spec compile_resource(module(), module(), String.t()) :: module()
  defp compile_resource(domain, resource, body) do
    source = """
    defmodule #{inspect(domain)} do
      use Ash.Domain, validate_config_inclusion?: false

      resources do
        allow_unregistered? true
      end
    end

    defmodule #{inspect(resource)} do
      use Ash.Resource, domain: #{inspect(domain)}, data_layer: Ash.DataLayer.Ets

      #{body}

      attributes do
        uuid_primary_key :id
      end
    end
    """

    ExUnit.CaptureIO.capture_io(:stderr, fn -> Code.compile_string(source) end)
    resource
  end

  @doc "Returns the vertex of a signal."
  @spec signal(module(), atom()) :: Signal.t()
  def signal(module, name), do: %Signal{signal_module: module, signal: Info.signal(module, name)}

  @doc "Returns the vertex of an action."
  @spec action(module(), atom()) :: Action.t()
  def action(resource, name),
    do: %Action{action: Ash.Resource.Info.action(resource, name), resource: resource}
end
