defmodule Clarity.Content.Ash.SignalFlowTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Ash.SignalFlow
  alias Clarity.Graph
  alias Clarity.Test.SignalGraph
  alias Clarity.Vertex.Ash.Action
  alias Clarity.Vertex.Ash.Signal
  alias Demo.Accounts.AuditEvent
  alias Demo.Billing.Invoice
  alias Demo.Billing.Signals
  alias Demo.Billing.Subscription

  setup do
    {:ok, graph: SignalGraph.build()}
  end

  @spec lines(Graph.t(), [atom()]) :: [String.t()]
  defp lines(graph, names) do
    graph
    |> SignalFlow.diagram(Enum.map(names, &signal/1))
    |> IO.iodata_to_binary()
    |> String.split("\n", trim: true)
  end

  @spec signal(atom()) :: Signal.t()
  defp signal(name), do: SignalGraph.signal(Signals, name)

  @spec action(module(), atom()) :: Action.t()
  defp action(resource, name), do: SignalGraph.action(resource, name)

  @spec id(Action.t() | Signal.t()) :: String.t()
  defp id(vertex), do: SignalFlow.node_id(vertex)

  @spec line(Action.t() | Signal.t(), String.t(), Action.t() | Signal.t()) :: String.t()
  defp line(from, arrow \\ "-->", to), do: "  #{id(from)} #{arrow} #{id(to)}"

  test "draws a flowchart from a signal's emitters, with the signal outlined", %{graph: graph} do
    lines = lines(graph, [:invoice_finalized])
    finalize = action(Invoice, :finalize)
    finalized = signal(:invoice_finalized)

    assert hd(lines) == "flowchart LR"
    assert ~s(  #{id(finalize)}["Billing.Invoice.finalize"]) in lines
    assert ~s(  #{id(finalized)}{{"invoice_finalized"}}) in lines
    assert line(finalize, finalized) in lines
    assert "  class #{id(finalized)} seed" in lines
  end

  test "follows the chain forward through the signals that its listeners emit", %{graph: graph} do
    lines = lines(graph, [:invoice_written_off])
    final_dunning = action(Subscription, :final_dunning)

    for expected <- [
          line(action(Invoice, :give_up), signal(:invoice_written_off)),
          line(signal(:invoice_written_off), final_dunning),
          line(final_dunning, signal(:subscription_canceled)),
          line(signal(:subscription_canceled), action(AuditEvent, :record_subscription_canceled))
        ] do
      assert expected in lines, "missing: #{expected}"
    end

    refute Enum.any?(lines, &(&1 =~ "user_cancels"))
    refute Enum.any?(lines, &(&1 =~ "invoice_paid"))
    refute "  class #{id(signal(:subscription_canceled))} seed" in lines
  end

  test "goes back only one step, to the signal's emitters", %{graph: graph} do
    lines = lines(graph, [:subscription_canceled])

    assert line(action(Subscription, :user_cancels), signal(:subscription_canceled)) in lines
    assert line(action(Subscription, :final_dunning), signal(:subscription_canceled)) in lines
    refute Enum.any?(lines, &(&1 =~ "invoice_written_off"))
  end

  test "dashes the line to a listener that a delivery other than Inline runs", %{graph: graph} do
    thank = action(Demo.Helpdesk.CustomerContact, :thank_for_payment)

    assert line(signal(:invoice_paid), "-.->", thank) in lines(graph, [:invoice_paid])
  end

  test "names a phase other than after_action", %{graph: graph} do
    lines = lines(graph, [:invoice_paid, :invoice_finalized])

    assert ~s(  #{id(signal(:invoice_paid))}{{"invoice_paid<br/><i>after transaction</i>"}}) in lines
    assert ~s(  #{id(signal(:invoice_finalized))}{{"invoice_finalized"}}) in lines
  end

  test "stops at a cycle", %{graph: graph} do
    final_dunning = action(Subscription, :final_dunning)
    Graph.add_edge(graph, final_dunning, signal(:invoice_written_off), :emits)

    lines = lines(graph, [:invoice_written_off])

    assert line(final_dunning, signal(:invoice_written_off)) in lines
    assert line(signal(:invoice_written_off), final_dunning) in lines
  end

  test "gives each node its own id, also when names differ only in punctuation" do
    question = %Action{action: %{name: :paid?}, resource: Invoice}
    bang = %Action{action: %{name: :paid!}, resource: Invoice}

    refute id(question) == id(bang)
    assert id(question) =~ ~r/^a_\w+$/
  end
end
