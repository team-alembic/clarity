defmodule Clarity.ReportTest do
  # async: false — registers reports in the global :clarity_reports env.
  use ExUnit.Case, async: false

  alias Clarity.Perspective.Lens
  alias Clarity.Report

  doctest Report

  defmodule SecurityReport do
    @moduledoc false
    @behaviour Report

    @impl Report
    def name, do: "Security Report"

    @impl Report
    def description, do: "A security report"

    @impl Report
    def applies?(%Lens{id: "security"}), do: true
    def applies?(_lens), do: false
  end

  defmodule ArchitectReport do
    @moduledoc false
    @behaviour Report

    @impl Report
    def name, do: "Architect Report"

    @impl Report
    def applies?(%Lens{id: "architect"}), do: true
    def applies?(_lens), do: false
  end

  setup do
    on_exit(fn -> Application.delete_env(:clarity, :clarity_reports) end)
  end

  @spec lens(String.t()) :: Lens.t()
  defp lens(id), do: %Lens{id: id, name: id, icon: fn -> nil end, filter: true}

  describe "report_id/1" do
    test "slugs the module, stripping the clarity-report prefix" do
      assert Report.report_id(Clarity.Report.SupplyChain) == "supply-chain"
    end
  end

  describe "applicable/1" do
    test "returns only reports that apply to the lens, sorted by name" do
      Application.put_env(:clarity, :clarity_reports, [SecurityReport, ArchitectReport])

      assert Report.applicable(lens("security")) == [SecurityReport]
      assert Report.applicable(lens("architect")) == [ArchitectReport]
      assert Report.applicable(lens("debug")) == []
    end
  end

  describe "fetch/2" do
    test "finds an applicable report by id" do
      Application.put_env(:clarity, :clarity_reports, [SecurityReport])

      assert {:ok, SecurityReport} = Report.fetch(lens("security"), Report.report_id(SecurityReport))
      assert :error = Report.fetch(lens("security"), "nope")
      # not applicable to this lens
      assert :error = Report.fetch(lens("architect"), Report.report_id(SecurityReport))
    end
  end

  describe "description/1" do
    test "returns the description or nil when undefined" do
      assert Report.description(SecurityReport) == "A security report"
      assert Report.description(ArchitectReport) == nil
    end
  end
end
