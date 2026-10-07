defmodule Clarity.Perspective.InternalsTest do
  use ExUnit.Case, async: true

  alias Clarity.Perspective.Internals
  alias Clarity.Test.Helper
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain

  describe inspect(&Internals.internal?/1) do
    test "Ash's shadow domains are internal" do
      assert Internals.internal?(%Domain{domain: Ash.EmbeddableType.ShadowDomain})
      assert Internals.internal?(%Domain{domain: Ash.Filter.ShadowDomain})
    end

    test "the application's own domains are not" do
      refute Internals.internal?(%Domain{domain: Demo.Accounts})
    end

    test "other vertices are not" do
      refute Internals.internal?(%Vertex.Ash.Resource{resource: Demo.Accounts.User})
      refute Internals.internal?(%Vertex.Root{})
    end
  end

  describe inspect(&Internals.ids/1) do
    test "lists the internal vertices in the graph" do
      graph = Helper.build_test_clarity(internals: true).graph

      assert Internals.ids(graph) == ["ash-domain:ash-embeddable-type-shadow-domain"]
    end
  end
end
