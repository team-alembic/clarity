defmodule Clarity.Introspector.Ash.SignalTest do
  use ExUnit.Case, async: true

  alias Clarity.Graph
  alias Clarity.Introspector.Ash.Signal, as: SignalIntrospector
  alias Clarity.Test.SignalGraph
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Ash.Signal
  alias Clarity.Vertex.Ash.SignalModule
  alias Clarity.Vertex.Root
  alias Demo.Billing.Invoice
  alias Demo.Billing.Plan
  alias Demo.Billing.Signals
  alias Demo.Billing.Subscription

  describe "a module" do
    test "becomes a signal module under the domain it's named under" do
      graph = Graph.new()
      domain_vertex = %Domain{domain: Demo.Billing}
      Graph.add_vertex(graph, domain_vertex, %Root{})
      module_vertex = %Vertex.Module{module: Signals}
      signal_module_vertex = %SignalModule{signal_module: Signals}

      assert {:ok,
              [
                {:vertex, ^signal_module_vertex},
                {:edge, ^domain_vertex, ^signal_module_vertex, :signal_module},
                {:edge, ^module_vertex, ^signal_module_vertex, :signal_module}
              ]} = SignalIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "waits for the domain it's named under" do
      assert {:error, {:unmet_dependencies, [Demo.Billing]}} =
               SignalIntrospector.introspect_vertex(%Vertex.Module{module: Signals}, Graph.new())
    end

    test "becomes a signal module under its application when no domain names it" do
      graph = Graph.new()

      app_vertex = %Vertex.Application{
        app: :clarity,
        description: "Clarity",
        version: Version.parse!("0.4.0")
      }

      Graph.add_vertex(graph, app_vertex, %Root{})
      signal_module_vertex = %SignalModule{signal_module: Demo.Signals}

      assert {:ok,
              [
                {:vertex, ^signal_module_vertex},
                {:edge, ^app_vertex, ^signal_module_vertex, :signal_module},
                _module_edge
              ]} = SignalIntrospector.introspect_vertex(%Vertex.Module{module: Demo.Signals}, graph)
    end

    test "ignores modules that aren't signal modules" do
      assert {:ok, []} =
               SignalIntrospector.introspect_vertex(%Vertex.Module{module: Invoice}, Graph.new())
    end
  end

  describe "a domain" do
    test "links to the signal modules already in the graph that are nested under it" do
      graph = Graph.new()
      billing = %SignalModule{signal_module: Signals}
      platform = %SignalModule{signal_module: Demo.Signals}
      Graph.add_vertex(graph, billing, %Root{})
      Graph.add_vertex(graph, platform, %Root{})
      domain_vertex = %Domain{domain: Demo.Billing}

      assert {:ok, [{:edge, ^domain_vertex, ^billing, :signal_module}]} =
               SignalIntrospector.introspect_vertex(domain_vertex, graph)
    end

    test "doesn't link to a signal module twice" do
      graph = Graph.new()
      domain_vertex = %Domain{domain: Demo.Billing}
      billing = %SignalModule{signal_module: Signals}
      Graph.add_vertex(graph, domain_vertex, %Root{})
      Graph.add_vertex(graph, billing, domain_vertex)
      Graph.add_edge(graph, domain_vertex, billing, :signal_module)

      assert {:ok, []} = SignalIntrospector.introspect_vertex(domain_vertex, graph)
    end
  end

  describe "a domain that is introspected again" do
    test "keeps its signal modules and their signals in the tree" do
      graph = Graph.new()

      app_vertex = %Vertex.Application{
        app: :clarity,
        description: "Clarity",
        version: Version.parse!("0.4.0")
      }

      domain_vertex = %Domain{domain: Demo.Billing}
      module_vertex = %Vertex.Module{module: Signals}
      Graph.add_vertex(graph, app_vertex, %Root{})
      Graph.add_edge(graph, %Root{}, app_vertex, :application)
      Graph.add_vertex(graph, domain_vertex, app_vertex)
      Graph.add_edge(graph, app_vertex, domain_vertex, :domain)
      Graph.add_vertex(graph, module_vertex, app_vertex)
      Graph.add_edge(graph, app_vertex, module_vertex, :module)

      introspect(graph, module_vertex)
      introspect(graph, %SignalModule{signal_module: Signals})

      {:ok, _purged} = Graph.purge(graph, domain_vertex)
      Graph.add_vertex(graph, domain_vertex, app_vertex)
      Graph.add_edge(graph, app_vertex, domain_vertex, :domain)
      introspect(graph, domain_vertex)

      signal_vertex = SignalGraph.signal(Signals, :invoice_paid)

      assert graph |> Graph.breadcrumbs(signal_vertex) |> Enum.map(&Vertex.id/1) == [
               "root",
               Vertex.id(app_vertex),
               Vertex.id(domain_vertex),
               Vertex.id(%SignalModule{signal_module: Signals}),
               Vertex.id(signal_vertex)
             ]
    end
  end

  describe "a signal module" do
    test "declares a vertex for each of its signals" do
      signal_module_vertex = %SignalModule{signal_module: Signals}

      assert {:ok, entries} = SignalIntrospector.introspect_vertex(signal_module_vertex, Graph.new())

      assert for({:vertex, %Signal{signal: %{name: name}}} <- entries, do: name) ==
               [:invoice_finalized, :invoice_paid, :invoice_written_off, :subscription_canceled]

      for {:vertex, signal_vertex} <- entries do
        assert {:edge, signal_module_vertex, signal_vertex, :signal} in entries
      end
    end
  end

  describe "an action" do
    test "links to the signals it emits" do
      graph = Graph.new()
      signal_vertex = SignalGraph.signal(Signals, :invoice_finalized)
      Graph.add_vertex(graph, signal_vertex, %Root{})
      action_vertex = SignalGraph.action(Invoice, :finalize)

      assert {:ok, [{:edge, ^action_vertex, ^signal_vertex, :emits}]} =
               SignalIntrospector.introspect_vertex(action_vertex, graph)
    end

    test "is linked from the signals that its resource's listeners run it for" do
      graph = Graph.new()
      written_off = SignalGraph.signal(Signals, :invoice_written_off)
      canceled = SignalGraph.signal(Signals, :subscription_canceled)
      Graph.add_vertex(graph, written_off, %Root{})
      Graph.add_vertex(graph, canceled, %Root{})
      action_vertex = SignalGraph.action(Subscription, :final_dunning)

      assert SignalIntrospector.introspect_vertex(action_vertex, graph) ==
               {:ok,
                [
                  {:edge, action_vertex, canceled, :emits},
                  {:edge, written_off, action_vertex, :triggers}
                ]}
    end

    test "waits for the vertices of the signals it refers to" do
      assert {:error, {:unmet_dependencies, [Signals]}} =
               SignalIntrospector.introspect_vertex(
                 SignalGraph.action(Subscription, :final_dunning),
                 Graph.new()
               )
    end

    test "doesn't link to a signal twice" do
      graph = Graph.new()
      signal_vertex = SignalGraph.signal(Signals, :invoice_finalized)
      action_vertex = SignalGraph.action(Invoice, :finalize)
      Graph.add_vertex(graph, signal_vertex, %Root{})
      Graph.add_vertex(graph, action_vertex, %Root{})
      Graph.add_edge(graph, action_vertex, signal_vertex, :emits)

      assert {:ok, []} = SignalIntrospector.introspect_vertex(action_vertex, graph)
    end

    test "doesn't link to, or wait for, a signal that doesn't exist" do
      action = %{
        name: :touch,
        emits: [
          %{signal_module: Signals, signal: :no_such_signal},
          %{signal_module: Enum, signal: :reduced}
        ]
      }

      action_vertex = %Vertex.Ash.Action{action: action, resource: Invoice}

      assert {:ok, []} = SignalIntrospector.introspect_vertex(action_vertex, Graph.new())
    end

    test "ignores actions without signals" do
      assert {:ok, []} =
               SignalIntrospector.introspect_vertex(SignalGraph.action(Invoice, :read), Graph.new())
    end
  end

  describe "a signal" do
    test "is linked from the actions already in the graph that emit it, or that listeners run for it" do
      graph = Graph.new()
      give_up = SignalGraph.action(Invoice, :give_up)
      final_dunning = SignalGraph.action(Subscription, :final_dunning)
      finalize = SignalGraph.action(Invoice, :finalize)
      read_plan = SignalGraph.action(Plan, :read)

      for vertex <- [
            %Resource{resource: Invoice},
            %Resource{resource: Subscription},
            %Resource{resource: Plan},
            give_up,
            final_dunning,
            finalize,
            read_plan
          ],
          do: Graph.add_vertex(graph, vertex, %Root{})

      signal_vertex = SignalGraph.signal(Signals, :invoice_written_off)

      assert {:ok, entries} = SignalIntrospector.introspect_vertex(signal_vertex, graph)

      assert Enum.sort(entries) ==
               Enum.sort([
                 {:edge, give_up, signal_vertex, :emits},
                 {:edge, signal_vertex, final_dunning, :triggers}
               ])
    end

    test "doesn't link an action twice" do
      graph = Graph.new()
      give_up = SignalGraph.action(Invoice, :give_up)
      signal_vertex = SignalGraph.signal(Signals, :invoice_written_off)
      Graph.add_vertex(graph, %Resource{resource: Invoice}, %Root{})
      Graph.add_vertex(graph, give_up, %Root{})
      Graph.add_vertex(graph, signal_vertex, %Root{})
      Graph.add_edge(graph, give_up, signal_vertex, :emits)

      assert {:ok, []} = SignalIntrospector.introspect_vertex(signal_vertex, graph)
    end
  end

  @spec introspect(Graph.t(), Vertex.t()) :: :ok
  defp introspect(graph, vertex) do
    {:ok, entries} = SignalIntrospector.introspect_vertex(vertex, graph)

    for {:vertex, new_vertex} <- entries, do: Graph.add_vertex(graph, new_vertex, vertex)
    for {:edge, from, to, label} <- entries, do: Graph.add_edge(graph, from, to, label)

    :ok
  end
end
