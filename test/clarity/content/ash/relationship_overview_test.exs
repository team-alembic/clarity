defmodule Clarity.Content.Ash.RelationshipOverviewTest do
  use ExUnit.Case, async: true

  import Clarity.Test.OverviewHelper

  alias Ash.Resource.Info
  alias Clarity.Content.Ash.RelationshipOverview
  alias Clarity.Vertex.Ash.Relationship
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User
  alias Demo.Projects.Ticket

  describe inspect(&RelationshipOverview.name/0) do
    test "returns relationship overview name" do
      assert RelationshipOverview.name() == "Relationship Overview"
    end
  end

  describe inspect(&RelationshipOverview.description/0) do
    test "returns relationship overview description" do
      assert RelationshipOverview.description() == "Overview of this Ash relationship"
    end
  end

  describe inspect(&RelationshipOverview.applies?/2) do
    test "returns true for Relationship vertices" do
      relationships = Info.relationships(User)

      if relationships != [] do
        [relationship | _] = relationships
        vertex = %Relationship{relationship: relationship, resource: User}
        lens = nil

        assert RelationshipOverview.applies?(vertex, lens)
      end
    end

    test "returns false for non-relationship vertices" do
      vertex = %Root{}
      lens = nil

      refute RelationshipOverview.applies?(vertex, lens)
    end
  end

  describe "render" do
    test "leads with the relationship as a sentence, and how the keys join" do
      ticket = Ticket

      html =
        render_overview(RelationshipOverview, %Relationship{
          relationship: Info.relationship(ticket, :project),
          resource: ticket
        })

      assert text(html, ".ov-headline") == "Ticket belongs to one Project"
      assert texts(html, ".ov-join") == ["Ticket . project_id → Project . id"]
    end

    test "joins a many-to-many through its join resource" do
      ticket = Ticket

      html =
        render_overview(RelationshipOverview, %Relationship{
          relationship: Info.relationship(ticket, :labels),
          resource: ticket
        })

      assert text(html, ".ov-headline") == "Ticket has many Label through TicketLabel"

      assert texts(html, ".ov-join") == [
               "Ticket . id → TicketLabel . ticket_id",
               "TicketLabel . label_id → Label . id"
             ]
    end
  end
end
