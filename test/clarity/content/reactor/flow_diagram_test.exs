defmodule Clarity.Content.Reactor.FlowDiagramTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Content.Reactor.FlowDiagram
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Action
  alias Demo.Billing.IssueInvoice
  alias Demo.Billing.Subscription

  describe inspect(&FlowDiagram.applies?/2) do
    test "applies to reactors and to the actions that run them" do
      assert FlowDiagram.applies?(%Vertex.Reactor{reactor: IssueInvoice}, nil)
      assert FlowDiagram.applies?(action_vertex(:issue_invoice), nil)
    end

    test "doesn't apply to other actions or vertices" do
      refute FlowDiagram.applies?(action_vertex(:convert), nil)
      refute FlowDiagram.applies?(%Vertex.Module{module: IssueInvoice}, nil)
    end
  end

  describe inspect(&FlowDiagram.render_static/2) do
    setup do
      %{lines: IssueInvoice |> diagram() |> String.split("\n", trim: true)}
    end

    test "draws inputs and steps, in the order they're defined", %{lines: lines} do
      nodes = Enum.filter(lines, &String.match?(&1, ~r/^\s+(input|step)_\w+[>\[{(]/))

      assert [
               "  input_subscription_id>" <> _,
               "  step_load_subscription[" <> _,
               "  step_price_period{" <> _,
               "    step_no_charge[" <> _,
               "    step_price_seats[" <> _,
               "  step_draft_invoice[" <> _,
               "  step_charge_payment_method[" <> _,
               "  step_email_receipt[" <> _
             ] = nodes
    end

    test "draws each branch of a switch, both feeding the step that uses its result", %{
      lines: lines
    } do
      assert ~s(  subgraph step_price_period_match_1 ["match 1"]) in lines
      assert ~s(  subgraph step_price_period_default ["default"]) in lines
      assert "  step_price_period --> step_price_period_match_1" in lines
      assert "  step_price_period --> step_price_period_default" in lines
      assert "  step_load_subscription --> step_price_period" in lines
      assert "  step_no_charge -->|total_cents| step_draft_invoice" in lines
      assert "  step_price_seats -->|total_cents| step_draft_invoice" in lines
    end

    test "labels edges with the argument they fill", %{lines: lines} do
      assert "  input_subscription_id -->|id| step_load_subscription" in lines
      assert "  step_draft_invoice -->|invoice| step_charge_payment_method" in lines
    end

    test "marks steps that undo or compensate, and the step the reactor returns", %{
      lines: lines
    } do
      assert Enum.any?(lines, &(&1 =~ "step_draft_invoice[" and &1 =~ "undo"))
      assert Enum.any?(lines, &(&1 =~ "step_charge_payment_method[" and &1 =~ "compensate"))
      assert "  class step_draft_invoice returned" in lines
    end

    test "draws the reactor an action runs" do
      assert {:mermaid, render} = FlowDiagram.render_static(action_vertex(:issue_invoice), nil)
      assert IO.iodata_to_binary(render.(%{})) == diagram(IssueInvoice)
    end
  end

  @spec diagram(module()) :: String.t()
  defp diagram(reactor) do
    assert {:mermaid, render} = FlowDiagram.render_static(%Vertex.Reactor{reactor: reactor}, nil)
    IO.iodata_to_binary(render.(%{}))
  end

  @spec action_vertex(atom()) :: Action.t()
  defp action_vertex(name) do
    %Action{action: Info.action(Subscription, name), resource: Subscription}
  end
end
