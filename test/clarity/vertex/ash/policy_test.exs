defmodule Clarity.Vertex.Ash.PolicyTest do
  use ExUnit.Case, async: true

  alias Ash.Policy.Info
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Policy
  alias Demo.Accounts.ApiToken
  alias Demo.Accounts.Membership
  alias Demo.Accounts.User
  alias Demo.Projects.Ticket

  # The resource's policies, as vertices, in declaration order.
  defp policies(resource), do: for(policy <- Info.policies(resource), do: %Policy{policy: policy, resource: resource})

  describe inspect(&Vertex.name/1) do
    test "names a policy by the actions it covers and what it requires" do
      [_bypass, read, _by_name] = policies(User)

      assert Vertex.name(read) == "read actions: authorize if id == actor.id"
    end

    test "names a policy on one action after that action" do
      [_bypass, _read, close, _reassign] = policies(Ticket)

      assert Vertex.name(close) == "close action: authorize if reporter_id == actor.id (+2)"
    end

    test "lists every action type a policy covers" do
      [_read, write] = policies(ApiToken)

      assert Vertex.name(write) == "create, destroy actions: authorize if actor.role in [:owner, :admin]"
    end

    test "leaves out checks that always authorize" do
      [_bypass, _read, by_name] = policies(User)

      assert Vertex.name(by_name) == "by_name action: forbid if actor is using an API key"
    end

    test "names a bypass by what grants it, whether that is its condition or its check" do
      [user_bypass | _rest] = policies(User)
      membership_bypass = Enum.find(policies(Membership), & &1.policy.bypass?)

      # bypass always() do authorize_if actor_attribute_equals(:admin, true)
      assert Vertex.name(user_bypass) == "bypass: actor.admin == true"
      # bypass actor_attribute_equals(:admin, true) do authorize_if always()
      assert Vertex.name(membership_bypass) == "bypass: actor.admin == true"
    end

    test "prefers the policy's own description" do
      [_bypass, read, _by_name] = policies(User)
      described = %{read | policy: %{read.policy | description: "Users can read themselves"}}

      assert Vertex.name(described) == "Users can read themselves"
    end
  end

  describe "Clarity.Vertex.HintProvider" do
    test "shows the resource, condition and checks in Ash's own words" do
      [bypass, _read, by_name] = policies(User)

      assert Vertex.HintProvider.icon(by_name) == :policy

      assert Vertex.HintProvider.facts(by_name) == [
               {"Resource", "Demo.Accounts.User"},
               {"Condition", "action == :by_name"},
               {"Checks", ["forbid if actor is using an API key", "authorize if always true"]}
             ]

      assert {"Condition", "always true"} in Vertex.HintProvider.facts(bypass)
    end

    test "reads actor references as actor.field" do
      [_read, write] = policies(ApiToken)

      assert {"Checks", ["authorize if actor.role in [:owner, :admin]"]} in Vertex.HintProvider.facts(write)
    end
  end
end
