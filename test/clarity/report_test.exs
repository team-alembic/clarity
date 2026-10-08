defmodule Clarity.ReportTest do
  # async: false — registers reports in the global :clarity_reports env.
  use ExUnit.Case, async: false

  alias Clarity.Report

  doctest Report

  defmodule ZebraReport do
    @moduledoc false
    @behaviour Report

    @impl Report
    def name, do: "Zebra Report"

    @impl Report
    def description, do: "A described report"
  end

  defmodule AardvarkReport do
    @moduledoc false
    @behaviour Report

    @impl Report
    def name, do: "Aardvark Report"
  end

  defmodule BillingReport do
    @moduledoc false
    @behaviour Report

    @impl Report
    def name, do: "Billing Report"

    @impl Report
    def category, do: "Finance"
  end

  defmodule AuditReport do
    @moduledoc false
    @behaviour Report

    @impl Report
    def name, do: "Audit Report"

    @impl Report
    def category, do: "Compliance"
  end

  setup do
    on_exit(fn -> Application.delete_env(:clarity, :clarity_reports) end)
  end

  describe "report_id/1" do
    test "slugs the module, stripping the clarity-report prefix" do
      assert Report.report_id(Clarity.Report.SupplyChain) == "supply-chain"
    end
  end

  describe "all/0" do
    test "returns every registered report, sorted by name" do
      Application.put_env(:clarity, :clarity_reports, [ZebraReport, AardvarkReport])

      assert Report.all() == [AardvarkReport, ZebraReport]
    end

    test "skips reports whose module isn't available" do
      Application.put_env(:clarity, :clarity_reports, [ZebraReport, Clarity.Report.Missing])

      assert Report.all() == [ZebraReport]
    end
  end

  describe "grouped/0" do
    test "groups reports by category, sorted, with uncategorised ones last" do
      Application.put_env(:clarity, :clarity_reports, [
        ZebraReport,
        BillingReport,
        AardvarkReport,
        AuditReport
      ])

      assert Report.grouped() == [
               {"Compliance", [AuditReport]},
               {"Finance", [BillingReport]},
               {nil, [AardvarkReport, ZebraReport]}
             ]
    end
  end

  describe "category/1" do
    test "returns the category or nil when undefined" do
      assert Report.category(BillingReport) == "Finance"
      assert Report.category(ZebraReport) == nil
    end
  end

  describe "fetch/1" do
    test "finds a registered report by id" do
      Application.put_env(:clarity, :clarity_reports, [ZebraReport])

      assert {:ok, ZebraReport} = Report.fetch(Report.report_id(ZebraReport))
      assert :error = Report.fetch("nope")
    end
  end

  describe "description/1" do
    test "returns the description or nil when undefined" do
      assert Report.description(ZebraReport) == "A described report"
      assert Report.description(AardvarkReport) == nil
    end
  end
end
