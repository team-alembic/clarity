defmodule Clarity.Ash.ProvenanceTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Ash.Provenance
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Aggregate
  alias Clarity.Vertex.Ash.Calculation
  alias Demo.Projects.Sprint

  @spec calculation(module(), atom()) :: Calculation.t()
  defp calculation(resource, name), do: %Calculation{calculation: Info.calculation(resource, name), resource: resource}

  @spec aggregate(module(), atom()) :: Aggregate.t()
  defp aggregate(resource, name), do: %Aggregate{aggregate: Info.aggregate(resource, name), resource: resource}

  # Each node as its path, kind and role, indented by depth.
  @spec outline(Provenance.tree(), non_neg_integer()) :: [String.t()]
  defp outline(tree, depth \\ 0) do
    via = tree.vertex |> then(fn _ -> tree.via end) |> Enum.map_join("", &"#{&1.relationship.name}.")
    kind = tree.vertex.__struct__ |> Module.split() |> List.last()
    repeat = if tree.repeat?, do: " again", else: ""
    line = String.duplicate("  ", depth) <> "#{via}#{Vertex.name(tree.vertex)} #{kind} #{tree.role}#{repeat}"
    [line | Enum.flat_map(tree.children, &outline(&1, depth + 1))]
  end

  describe inspect(&Provenance.of/1) do
    test "follows a calculation through aggregates down to the stored fields" do
      assert outline(Provenance.of(calculation(Demo.Billing.Invoice, :outstanding_cents))) == [
               "outstanding_cents Calculation root",
               "  status Attribute uses",
               "  total_cents Aggregate uses",
               "    line_items.total_cents Attribute reads"
             ]
    end

    test "follows relationships, and a module's loads, across resources" do
      assert outline(Provenance.of(calculation(Demo.Projects.Ticket, :assignee_name))) == [
               "assignee_name Calculation root",
               "  assignee.display_name Calculation uses",
               "    full_name Calculation loads",
               "      first_name Attribute uses",
               "      last_name Attribute uses",
               "    admin Attribute loads"
             ]
    end

    test "counts what an aggregate's filter narrows by, once each" do
      assert outline(Provenance.of(calculation(Sprint, :completion_ratio))) == [
               "completion_ratio Calculation root",
               "  ticket_count Aggregate uses",
               "  closed_ticket_count Aggregate uses",
               "    tickets.status Attribute filters"
             ]

      assert outline(Provenance.of(aggregate(Demo.Projects.Project, :total_time_minutes))) == [
               "total_time_minutes Aggregate root",
               "  tickets.time_entries.minutes Attribute reads"
             ]
    end

    test "reads an unrelated aggregate's records on the resource it names" do
      assert outline(Provenance.of(aggregate(Demo.Accounts.User, :admin_count))) == [
               "admin_count Aggregate root",
               "  admin Attribute filters"
             ]
    end
  end

  describe inspect(&Provenance.flatten/1) do
    test "returns each field once, and an edge from each to what reads it" do
      {fields, edges} = Provenance.flatten(Provenance.of(calculation(Sprint, :completion_ratio)))

      assert Enum.map(fields, &Vertex.name/1) ==
               ["completion_ratio", "ticket_count", "closed_ticket_count", "status"]

      assert Enum.map(edges, fn {from, to, _via, role} -> {Vertex.name(from), Vertex.name(to), role} end) == [
               {"ticket_count", "completion_ratio", :uses},
               {"closed_ticket_count", "completion_ratio", :uses},
               {"status", "closed_ticket_count", :filters}
             ]
    end
  end
end
