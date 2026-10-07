defmodule Clarity.Vertex.AdvisoryTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex

  describe "Clarity.Vertex.HintProvider" do
    test "shows the severity as a badge and the package and aliases as facts" do
      vertex = %Vertex.Advisory{
        advisory: %Clarity.Advisory{
          id: "GHSA-xxxx",
          package: "phoenix",
          severity: "high",
          aliases: ["CVE-2026-0001"]
        }
      }

      assert Vertex.HintProvider.icon(vertex) == :advisory
      assert Vertex.HintProvider.badges(vertex) == ["high"]

      assert Vertex.HintProvider.facts(vertex) == [
               {"Package", "phoenix"},
               {"Aliases", ["CVE-2026-0001"]}
             ]
    end

    test "omits a missing severity and empty aliases" do
      vertex = %Vertex.Advisory{advisory: %Clarity.Advisory{id: "GHSA-x", package: "mdex"}}

      assert Vertex.HintProvider.badges(vertex) == []
      assert Vertex.HintProvider.facts(vertex) == [{"Package", "mdex"}]
    end
  end
end
