defmodule Clarity.Content.Ash.AggregateOverviewTest do
  use ExUnit.Case, async: true

  import Clarity.Test.OverviewHelper

  alias Ash.Resource.Info
  alias Clarity.Content.Ash.AggregateOverview
  alias Clarity.Vertex.Ash.Aggregate
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

  describe inspect(&AggregateOverview.name/0) do
    test "returns aggregate overview name" do
      assert AggregateOverview.name() == "Aggregate Overview"
    end
  end

  describe inspect(&AggregateOverview.description/0) do
    test "returns aggregate overview description" do
      assert AggregateOverview.description() == "Overview of this Ash aggregate"
    end
  end

  describe inspect(&AggregateOverview.applies?/2) do
    test "returns true for Aggregate vertices" do
      aggregates = Info.aggregates(User)

      if aggregates != [] do
        [aggregate | _] = aggregates
        vertex = %Aggregate{aggregate: aggregate, resource: User}
        lens = nil

        assert AggregateOverview.applies?(vertex, lens)
      end
    end

    test "returns false for non-aggregate vertices" do
      vertex = %Root{}
      lens = nil

      refute AggregateOverview.applies?(vertex, lens)
    end
  end

  describe "render" do
    test "leads with what it computes and returns, and the path it reads along" do
      invoice = Demo.Billing.Invoice

      html =
        render_overview(AggregateOverview, %Aggregate{aggregate: Info.aggregate(invoice, :total_cents), resource: invoice})

      assert text(html, ".ov-headline") == "sum of line_items.total_cents returning integer"
      assert texts(html, ".ov-join") == ["Invoice → line_items → LineItem . total_cents"]
      assert Enum.empty?(LazyHTML.query(html, "#provenance")), "the path already shows where it reads"
    end

    test "links the fields its filter names on the related records, and what it reads by them" do
      project = Demo.Projects.Project

      html =
        render_overview(AggregateOverview, %Aggregate{
          aggregate: Info.aggregate(project, :open_ticket_count),
          resource: project
        })

      assert html
             |> LazyHTML.query(".ov-fact .ov-expr-ref")
             |> LazyHTML.attribute("href") == ["/c/architect/ash-attribute:demo-projects-ticket:status"]

      assert texts(html, "#provenance .ov-source") == ["tickets . status atom stored filter"]
    end
  end
end
