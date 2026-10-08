defmodule Clarity.Content.Ash.CalculationOverviewTest do
  use ExUnit.Case, async: true

  import Clarity.Test.OverviewHelper

  alias Ash.Resource.Info
  alias Clarity.Content.Ash.CalculationOverview
  alias Clarity.Vertex.Ash.Calculation
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User

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
  end
end
