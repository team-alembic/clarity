defmodule Clarity.Vertex.Ash.PolicyTest do
  use ExUnit.Case, async: true

  alias Ash.Policy.Info
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Policy
  alias Demo.Accounts.User

  describe "Clarity.Vertex.HintProvider" do
    test "shows the resource, condition and checks in Ash's own words" do
      [bypass, _read, by_name] = Info.policies(User)
      vertex = %Policy{policy: by_name, resource: User}

      assert Vertex.HintProvider.icon(vertex) == :policy

      assert Vertex.HintProvider.facts(vertex) == [
               {"Resource", "Demo.Accounts.User"},
               {"Condition", "action == :by_name"},
               {"Checks", ["forbid_if actor is using an API key", "authorize_if always true"]}
             ]

      assert {"Condition", "always true"} in Vertex.HintProvider.facts(%Policy{policy: bypass, resource: User})
    end
  end
end
