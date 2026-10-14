defmodule Clarity.Content.Ash.SignalOverviewTest do
  use ExUnit.Case, async: true

  import Clarity.Test.OverviewHelper

  alias Clarity.Content.Ash.SignalOverview
  alias Clarity.Test.SignalGraph
  alias Clarity.Vertex.Ash.Resource
  alias Demo.Billing.Signals

  describe inspect(&SignalOverview.applies?/2) do
    test "applies to signals, and nothing else" do
      assert SignalOverview.applies?(SignalGraph.signal(Signals, :invoice_paid), nil)
      refute SignalOverview.applies?(%Resource{resource: Demo.Billing.Invoice}, nil)
    end
  end

  test "explains the :integrity status class" do
    assert SignalOverview.status_classes() == [:integrity]
  end

  describe "render" do
    setup do
      {:ok, graph: SignalGraph.build()}
    end

    test "leads with the signal's module, then lists its payload", %{graph: graph} do
      html =
        render_overview(SignalOverview, SignalGraph.signal(Signals, :invoice_written_off), graph: graph)

      assert text(html, ".ov-headline") =~ ~r/in\s*Signals/

      assert texts(html, "#signal-payload tbody tr td:first-child") == [
               "signal_id",
               "invoice_id",
               "subscription_id"
             ]

      assert texts(html, "#signal-payload tbody tr td:nth-child(3) .ov-flags") == [
               "",
               "required",
               "required"
             ]
    end

    test "lists the actions that emit it, and how they fill it", %{graph: graph} do
      html =
        render_overview(SignalOverview, SignalGraph.signal(Signals, :subscription_canceled), graph: graph)

      emitters = text(html, "#signal-emitters")

      assert emitters =~ "final_dunning"
      assert emitters =~ "user_cancels"
      assert emitters =~ "fields: [subscription_id: :id]"
    end

    test "lists its listeners, with the action each runs and its delivery", %{graph: graph} do
      html = render_overview(SignalOverview, SignalGraph.signal(Signals, :invoice_paid), graph: graph)
      listeners = text(html, "#signal-listeners")

      assert listeners =~ "thank_for_payment"
      assert listeners =~ "AshOban.Signals [queue: :default]"
    end

    test "says when nothing listens to it", %{graph: graph} do
      html =
        render_overview(SignalOverview, SignalGraph.signal(Signals, :invoice_finalized), graph: graph)

      assert text(html, "#listeners") =~ "No listener"
    end

    test "draws the flow from the signal", %{graph: graph} do
      html = render_overview(SignalOverview, SignalGraph.signal(Signals, :invoice_paid), graph: graph)
      [diagram] = html |> LazyHTML.query("#signal-flow") |> LazyHTML.attribute("data-graph")

      assert diagram =~ "flowchart LR"
      assert diagram =~ "a_Demo_Helpdesk_CustomerContact_thank_for_payment"
    end
  end
end
