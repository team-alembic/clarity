defmodule Clarity.Content.Ash.SignalsOverviewTest do
  use ExUnit.Case, async: true

  import Clarity.Test.OverviewHelper

  alias Clarity.Content.Ash.SignalFlow
  alias Clarity.Content.Ash.SignalsOverview
  alias Clarity.Test.SignalGraph
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Ash.SignalModule
  alias Demo.Billing.Invoice
  alias Demo.Billing.Signals
  alias Demo.Billing.Subscription

  @app %Vertex.Application{app: :clarity, description: "Clarity", version: Version.parse!("0.4.0")}

  describe inspect(&SignalsOverview.applies?/2) do
    test "applies where signals are emitted, listened to or declared" do
      for vertex <- [
            SignalGraph.action(Invoice, :finalize),
            SignalGraph.action(Demo.Helpdesk.CustomerContact, :thank_for_payment),
            %Resource{resource: Subscription},
            %SignalModule{signal_module: Signals},
            %SignalModule{signal_module: Demo.Signals},
            %Domain{domain: Demo.Billing},
            %Domain{domain: Demo.Accounts},
            %Domain{domain: Demo.Helpdesk},
            @app
          ] do
        assert SignalsOverview.applies?(vertex, nil), "should apply to #{Vertex.id(vertex)}"
      end
    end

    test "doesn't apply where there are none" do
      for vertex <- [
            SignalGraph.action(Invoice, :read),
            %Resource{resource: Demo.Billing.Plan},
            %Domain{domain: Demo.Projects},
            SignalGraph.signal(Signals, :invoice_paid)
          ] do
        refute SignalsOverview.applies?(vertex, nil), "shouldn't apply to #{Vertex.id(vertex)}"
      end
    end
  end

  describe "render" do
    setup do
      {:ok, graph: SignalGraph.build()}
    end

    test "lists a domain's signals, each linking to its own page", %{graph: graph} do
      html = render_overview(SignalsOverview, %Domain{domain: Demo.Billing}, graph: graph)

      assert texts(html, "#signals-table tbody tr td:first-child") == [
               "invoice_finalized",
               "invoice_paid",
               "invoice_written_off",
               "subscription_canceled"
             ]

      [href | _] =
        html
        |> LazyHTML.query("#signals-table tbody tr td:first-child a")
        |> LazyHTML.attribute("href")

      assert href == "/c/architect/" <> Vertex.id(SignalGraph.signal(Signals, :invoice_finalized))
    end

    test "counts each signal's emitters and listeners, and names their deliveries", %{graph: graph} do
      html = render_overview(SignalsOverview, %Resource{resource: Subscription}, graph: graph)

      assert texts(html, "#signals-table tbody tr td:first-child") == [
               "invoice_written_off",
               "subscription_canceled"
             ]

      assert texts(html, "#signals-table tbody tr td:nth-child(3)") == ["1", "2"]
      assert texts(html, "#signals-table tbody tr td:nth-child(4)") == ["1", "1"]

      assert texts(html, "#signals-table tbody tr td:nth-child(5)") == [
               "Ash.Signals.Delivery.Inline",
               "Ash.Signals.Delivery.Inline"
             ]
    end

    test "draws the flow of its signals, outlined", %{graph: graph} do
      html = render_overview(SignalsOverview, %Domain{domain: Demo.Accounts}, graph: graph)
      [diagram] = html |> LazyHTML.query("#signals-flow") |> LazyHTML.attribute("data-graph")

      canceled = SignalGraph.signal(Signals, :subscription_canceled)

      assert diagram =~ "class #{SignalFlow.node_id(canceled)} seed"
    end
  end
end
