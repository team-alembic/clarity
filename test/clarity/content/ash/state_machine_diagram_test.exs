defmodule Clarity.Content.Ash.StateMachineDiagramTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Ash.StateMachineDiagram
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
  alias Demo.Helpdesk.Ticket

  describe inspect(&StateMachineDiagram.applies?/2) do
    test "applies to resources that use AshStateMachine" do
      assert StateMachineDiagram.applies?(%Resource{resource: Ticket}, nil)
    end

    test "doesn't apply to other resources or vertices" do
      refute StateMachineDiagram.applies?(%Resource{resource: Demo.Accounts.User}, nil)
      refute StateMachineDiagram.applies?(%Root{}, nil)
    end
  end

  describe inspect(&StateMachineDiagram.render_static/2) do
    test "draws every state and transition, from the initial states to the final ones" do
      assert diagram(Ticket) == """
             stateDiagram-v2
               direction LR
               state "new" as s_new
               state "open" as s_open
               state "pending" as s_pending
               state "resolved" as s_resolved
               state "closed" as s_closed
               [*] --> s_new
               s_new --> s_open : assign
               s_open --> s_pending : await_customer
               s_pending --> s_open : reply_received
               s_open --> s_resolved : resolve
               s_resolved --> s_open : reopen
               s_resolved --> s_closed : auto_close_after_7d
               s_closed --> [*]
             """
    end

    test "draws a transition from several states as one edge from each" do
      lines = Demo.Billing.Invoice |> diagram() |> String.split("\n", trim: true)

      assert "  s_sent --> s_paid : payment_received" in lines
      assert "  s_overdue --> s_paid : payment_received" in lines
      assert "  s_paid --> [*]" in lines
      assert "  s_written_off --> [*]" in lines
      refute "  s_overdue --> [*]" in lines
    end
  end

  defp diagram(resource) do
    assert {:mermaid, render} =
             StateMachineDiagram.render_static(%Resource{resource: resource}, nil)

    IO.iodata_to_binary(render.(%{}))
  end
end
