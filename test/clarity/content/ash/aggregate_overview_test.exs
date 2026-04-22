defmodule Clarity.Content.Ash.AggregateOverviewTest do
  use ExUnit.Case, async: true

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

  describe inspect(&AggregateOverview.render_static/2) do
    test "returns markdown tuple with function" do
      aggregates = Info.aggregates(User)

      if aggregates != [] do
        [aggregate | _] = aggregates
        vertex = %Aggregate{aggregate: aggregate, resource: User}
        lens = nil

        assert {:markdown, markdown_fn} = AggregateOverview.render_static(vertex, lens)
        assert is_function(markdown_fn, 1)
      end
    end

    test "generated markdown includes aggregate header" do
      aggregates = Info.aggregates(User)

      if aggregates != [] do
        [aggregate | _] = aggregates
        vertex = %Aggregate{aggregate: aggregate, resource: User}
        {:markdown, markdown_fn} = AggregateOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "# #{aggregate.name}"
        assert markdown =~ "**Kind:**"
      end
    end

    test "generated markdown includes aggregate information table" do
      aggregates = Info.aggregates(User)

      if aggregates != [] do
        [aggregate | _] = aggregates
        vertex = %Aggregate{aggregate: aggregate, resource: User}
        {:markdown, markdown_fn} = AggregateOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "## Aggregate Information"
        assert markdown =~ "| Property | Value |"
        assert markdown =~ "Demo.Accounts.User"
      end
    end

    test "generated markdown includes configuration section" do
      aggregates = Info.aggregates(User)

      if aggregates != [] do
        [aggregate | _] = aggregates
        vertex = %Aggregate{aggregate: aggregate, resource: User}
        {:markdown, markdown_fn} = AggregateOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "## Configuration"
        assert markdown =~ "Public"
      end
    end

    test "generated markdown includes target section" do
      aggregates = Info.aggregates(User)

      if aggregates != [] do
        [aggregate | _] = aggregates
        vertex = %Aggregate{aggregate: aggregate, resource: User}
        {:markdown, markdown_fn} = AggregateOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "## Target"
      end
    end

    test "generated markdown includes vertex links" do
      aggregates = Info.aggregates(User)

      if aggregates != [] do
        [aggregate | _] = aggregates
        vertex = %Aggregate{aggregate: aggregate, resource: User}
        {:markdown, markdown_fn} = AggregateOverview.render_static(vertex, nil)

        props = %{theme: :light, zoom_subgraph: nil}
        markdown = IO.iodata_to_binary(markdown_fn.(props))

        assert markdown =~ "vertex://ash-resource:demo-accounts-user"
      end
    end
  end
end
