defmodule Clarity.Graph.DOTTest do
  use ExUnit.Case, async: true

  alias Ash.Policy.Info, as: PolicyInfo
  alias Clarity.Graph
  alias Clarity.Graph.DOT
  alias Clarity.Vertex
  alias Demo.Accounts.User

  # The DOT label of the node for `vertex`, in a graph holding just it.
  @spec label(Vertex.t()) :: String.t()
  defp label(vertex) do
    graph = Graph.new()
    Graph.add_vertex(graph, vertex, %Vertex.Root{})
    dot = graph |> DOT.to_dot() |> IO.iodata_to_binary()
    [line] = for line <- String.split(dot, "\n"), line =~ ~s(URL = "##{Vertex.id(vertex)}"), do: line
    line
  end

  describe inspect(&DOT.to_dot/2) do
    test "labels a node with its type and name, and its detail when it has one" do
      [_bypass, read, _by_name] = PolicyInfo.policies(User)
      line = label(%Vertex.Ash.Policy{policy: read, resource: User})

      assert line =~ "Policy"
      assert line =~ "read"
      assert line =~ "id == actor.id"
    end

    test "labels a node without a detail with just its type and name" do
      line = label(%Vertex.Module{module: Demo.Accounts})

      assert line =~ ~r/Module<\/FONT><\/I><BR \/>Demo.Accounts>/
    end
  end
end
