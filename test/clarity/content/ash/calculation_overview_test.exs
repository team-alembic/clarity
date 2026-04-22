defmodule Clarity.Content.Ash.CalculationOverviewTest do
  use ExUnit.Case, async: true

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

  describe inspect(&CalculationOverview.render_static/2) do
    test "returns markdown tuple with function" do
      calculations = Info.calculations(User)

      if calculations != [] do
        [calculation | _] = calculations
        vertex = %Calculation{calculation: calculation, resource: User}
        lens = nil

        assert {:markdown, markdown_fn} = CalculationOverview.render_static(vertex, lens)
        assert is_function(markdown_fn, 1)
      end
    end

    test "generated markdown includes calculation header" do
      calculations = Info.calculations(User)

      if calculations != [] do
        [calculation | _] = calculations
        vertex = %Calculation{calculation: calculation, resource: User}
        {:markdown, markdown_fn} = CalculationOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "# #{calculation.name}"
        assert markdown =~ "**Type:**"
      end
    end

    test "generated markdown includes calculation information table" do
      calculations = Info.calculations(User)

      if calculations != [] do
        [calculation | _] = calculations
        vertex = %Calculation{calculation: calculation, resource: User}
        {:markdown, markdown_fn} = CalculationOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "## Calculation Information"
        assert markdown =~ "| Property | Value |"
        assert markdown =~ "Demo.Accounts.User"
      end
    end

    test "generated markdown includes configuration section" do
      calculations = Info.calculations(User)

      if calculations != [] do
        [calculation | _] = calculations
        vertex = %Calculation{calculation: calculation, resource: User}
        {:markdown, markdown_fn} = CalculationOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "## Configuration"
        assert markdown =~ "Public"
      end
    end

    test "generated markdown includes implementation section" do
      calculations = Info.calculations(User)

      if calculations != [] do
        [calculation | _] = calculations
        vertex = %Calculation{calculation: calculation, resource: User}
        {:markdown, markdown_fn} = CalculationOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "## Implementation"
      end
    end

    test "generated markdown includes vertex links" do
      calculations = Info.calculations(User)

      if calculations != [] do
        [calculation | _] = calculations
        vertex = %Calculation{calculation: calculation, resource: User}
        {:markdown, markdown_fn} = CalculationOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "vertex://ash-resource:demo-accounts-user"
      end
    end
  end
end
