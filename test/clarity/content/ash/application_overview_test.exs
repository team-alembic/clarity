defmodule Clarity.Content.Ash.ApplicationOverviewTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Ash.ApplicationOverview
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Root

  describe inspect(&ApplicationOverview.name/0) do
    test "returns application overview name" do
      assert ApplicationOverview.name() == "Application Overview"
    end
  end

  describe inspect(&ApplicationOverview.description/0) do
    test "returns application overview description" do
      assert ApplicationOverview.description() ==
               "Ash domains and resources defined in this application"
    end
  end

  describe inspect(&ApplicationOverview.applies?/2) do
    test "returns true for Application vertex with Ash domains" do
      vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}
      lens = nil

      assert ApplicationOverview.applies?(vertex, lens) == true
    end

    test "returns false for Application vertex without Ash domains" do
      vertex = %Application{app: :kernel, description: nil, version: "10.1"}
      lens = nil

      assert ApplicationOverview.applies?(vertex, lens) == false
    end

    test "returns false for non-Application vertices" do
      vertex = %Root{}
      lens = nil

      assert ApplicationOverview.applies?(vertex, lens) == false
    end
  end

  describe inspect(&ApplicationOverview.render_static/2) do
    test "returns markdown tuple with function" do
      vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}
      lens = nil

      assert {:markdown, markdown_fn} = ApplicationOverview.render_static(vertex, lens)
      assert is_function(markdown_fn, 1)
    end

    test "generated markdown includes Ash Domains header" do
      vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}
      {:markdown, markdown_fn} = ApplicationOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "## Ash Domains"
    end

    test "generated markdown includes domain sections" do
      vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}
      {:markdown, markdown_fn} = ApplicationOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "Demo.Accounts.Domain"
    end

    test "generated markdown includes resource tables" do
      vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}
      {:markdown, markdown_fn} = ApplicationOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "| Resource | Description |"
      assert markdown =~ "Demo.Accounts.User"
    end

    test "generated markdown includes vertex links" do
      vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}
      {:markdown, markdown_fn} = ApplicationOverview.render_static(vertex, nil)

      props = %{theme: :light, zoom_subgraph: nil}
      markdown = IO.iodata_to_binary(markdown_fn.(props))

      assert markdown =~ "vertex://ash-domain:demo-accounts-domain"
      assert markdown =~ "vertex://ash-resource:demo-accounts-user"
    end
  end
end
