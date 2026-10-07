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
  @spec policies(Ash.Resource.t()) :: [Policy.t()]
  defp policies(resource), do: for(policy <- Info.policies(resource), do: %Policy{policy: policy, resource: resource})

  # The tree shows a policy's name, then its detail in muted text.
  @spec label(Policy.t()) :: {String.t(), String.t() | nil}
  defp label(vertex), do: {Vertex.name(vertex), Vertex.DetailProvider.detail(vertex)}

  describe "name and detail" do
    test "name a policy by the actions it covers, with what it requires as the detail" do
      [_bypass, read, _by_name] = policies(User)

      assert label(read) == {"read", "id == actor.id"}
    end

    test "name a policy on one action after that action, counting further checks" do
      [_bypass, _read, close, _reassign] = policies(Ticket)

      assert label(close) == {"close", "reporter_id == actor.id +2"}
    end

    test "list every action type a policy covers" do
      [_read, write] = policies(ApiToken)

      assert label(write) == {"create, destroy", "actor.role in [:owner, :admin]"}
    end

    test "spell out checks that forbid, and leave out checks that always authorize" do
      [_bypass, _read, by_name] = policies(User)

      assert label(by_name) == {"by_name", "forbid if actor is using an API key"}
    end

    test "describe a bypass by what grants it, whether that is its condition or its check" do
      [user_bypass | _rest] = policies(User)
      membership_bypass = Enum.find(policies(Membership), & &1.policy.bypass?)

      # bypass always() do authorize_if actor_attribute_equals(:admin, true)
      assert label(user_bypass) == {"bypass", "actor.admin == true"}
      # bypass actor_attribute_equals(:admin, true) do authorize_if always()
      assert label(membership_bypass) == {"bypass", "actor.admin == true"}
    end

    test "prefer the policy's own description, with no detail" do
      [_bypass, read, _by_name] = policies(User)
      described = %{read | policy: %{read.policy | description: "Users can read themselves"}}

      assert label(described) == {"Users can read themselves", nil}
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
