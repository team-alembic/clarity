defmodule Clarity.Status.SignalIntegrityTest do
  use ExUnit.Case, async: true

  alias Clarity.Graph
  alias Clarity.Status
  alias Clarity.Status.SignalIntegrity
  alias Clarity.Test.SignalGraph
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
  alias Demo.Billing.Signals

  setup_all do
    {:ok, broken: SignalGraph.compile_broken(__MODULE__.Domain, __MODULE__.Broken)}
  end

  describe "a resource" do
    test "has an error for each signal verifier that rejects it", %{broken: broken} do
      vertex = %Resource{resource: broken}

      assert [
               %Status{severity: :error, class: :integrity, source: SignalIntegrity, message: emit},
               %Status{severity: :error, class: :integrity, source: SignalIntegrity, message: listener}
             ] = SignalIntegrity.statuses(vertex, Graph.new())

      assert emit =~ ~r/^actions -> update -> touch -> emit -> no_such_signal: /
      assert emit =~ "has no signal named `:no_such_signal`"
      assert listener =~ ~r/^signals_in -> from -> Demo\.Billing\.Signals -> on -> react: /
    end

    test "has none when its signals hold together" do
      assert SignalIntegrity.statuses(%Resource{resource: Demo.Billing.Subscription}, Graph.new()) == []
    end

    test "has none when the verifiers can't run" do
      assert SignalIntegrity.statuses(%Resource{resource: Clarity.NoSuchResource}, Graph.new()) == []
    end
  end

  describe "a signal" do
    setup do
      {:ok, graph: SignalGraph.build()}
    end

    test "is flagged when nothing listens to it", %{graph: graph} do
      assert [%Status{severity: :info, class: :integrity, message: "No listener"}] =
               SignalIntegrity.statuses(SignalGraph.signal(Signals, :invoice_finalized), graph)
    end

    test "is flagged when nothing listens to it and no action emits it", %{graph: graph} do
      statuses =
        SignalIntegrity.statuses(SignalGraph.signal(Demo.Signals, :maintenance_scheduled), graph)

      assert Enum.map(statuses, & &1.message) == ["No listener", "No action emits this signal"]
    end

    test "isn't flagged when it's emitted and listened to", %{graph: graph} do
      assert SignalIntegrity.statuses(SignalGraph.signal(Signals, :invoice_paid), graph) == []
    end

    test "counts the edges of the whole graph, not of a lens's view", %{graph: graph} do
      view = Graph.filter(graph, {:!=, :vertex_type, Clarity.Vertex.Ash.Action})

      assert SignalIntegrity.statuses(SignalGraph.signal(Signals, :invoice_paid), view) == []
    end
  end

  test "flags nothing else" do
    assert SignalIntegrity.statuses(%Root{}, Graph.new()) == []
  end
end
