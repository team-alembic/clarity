defmodule Clarity.Content.Ash.CalculationOverviewTest do
  use ExUnit.Case, async: true

  import Clarity.Test.OverviewHelper

  alias Ash.Resource.Info
  alias Clarity.Content.Ash.CalculationOverview
  alias Clarity.Vertex.Ash.Calculation
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User
  alias Demo.Projects.Ticket

  describe inspect(&CalculationOverview.name/0) do
    test "returns calculation overview name" do
      assert CalculationOverview.name() == "Calculation Overview"
    end
  end

  describe inspect(&CalculationOverview.description/0) do
    test "returns calculation overview description" do
      assert CalculationOverview.description() == "Overview of this Ash calculation"
    end
  end

  describe inspect(&CalculationOverview.applies?/2) do
    test "returns true for Calculation vertices" do
      calculations = Info.calculations(User)

      if calculations != [] do
        [calculation | _] = calculations
        vertex = %Calculation{calculation: calculation, resource: User}
        lens = nil

        assert CalculationOverview.applies?(vertex, lens)
      end
    end

    test "returns false for non-calculation vertices" do
      vertex = %Root{}
      lens = nil

      refute CalculationOverview.applies?(vertex, lens)
    end
  end

  @spec calculation(module(), atom()) :: Calculation.t()
  defp calculation(resource, name), do: %Calculation{calculation: Info.calculation(resource, name), resource: resource}

  describe "render" do
    test "leads with its type and resource, and its expression in full" do
      invoice = Demo.Billing.Invoice

      html =
        render_overview(CalculationOverview, %Calculation{
          calculation: Info.calculation(invoice, :days_overdue),
          resource: invoice
        })

      assert text(html, ".ov-headline") == "integer on Invoice by expression"
      assert text(html, "pre.ov-code-block") =~ "fragment("
    end

    test "links each field its expression names, with its hint" do
      html = render_overview(CalculationOverview, calculation(Ticket, :code))

      assert texts(html, "pre.ov-code-block a.ov-expr-ref") == ["project", "key", "position"]

      assert html
             |> LazyHTML.query(~s|pre a.ov-expr-ref[href="/c/architect/ash-attribute:demo-projects-project:key"]|)
             |> LazyHTML.attribute("data-tooltip-title") == ["key"]
    end

    test "explains the calculation's arguments on hover" do
      html = render_overview(CalculationOverview, calculation(User, :multi_arguments))

      assert html
             |> LazyHTML.query("pre .ov-expr-value")
             |> LazyHTML.attribute("data-tooltip-text")
             |> Enum.take(2) == ["The arg1 argument: string, required", "The arg2 argument: boolean, optional"]
    end

    test "shows where its value comes from, down to the stored fields, as a diagram and a tree" do
      html = render_overview(CalculationOverview, calculation(Ticket, :assignee_name))

      assert texts(html, "#provenance .ov-source-name") ==
               ["assignee . display_name", "full_name", "first_name", "last_name", "admin"]

      assert text(html, "#provenance .ov-section-aside") == "3 stored fields on 2 resources"
      assert [diagram] = html |> LazyHTML.query("#provenance-diagram") |> LazyHTML.attribute("data-graph")
      assert diagram =~ "cluster_Demo.Accounts.User"
      assert diagram =~ "label = <assignee>"
    end

    test "leaves out the diagram when the value comes straight from its own stored fields" do
      html = render_overview(CalculationOverview, calculation(Ticket, :is_overdue?))

      assert texts(html, "#provenance .ov-source-name") == ["due_at", "status"]
      assert Enum.empty?(LazyHTML.query(html, "#provenance-diagram"))
    end
  end
end
