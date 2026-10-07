defmodule Clarity.Ash.PolicyAnalysisTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Ash.PolicyAnalysis
  alias Demo.Accounts.Organization
  alias Demo.Accounts.User

  describe inspect(&PolicyAnalysis.action_verdict/3) do
    # :onboard is a generic action (type :action), run by a Reactor. No policy
    # but the admin bypass covers it.
    test "analyses generic actions" do
      onboard = Info.action(Organization, :onboard)

      assert PolicyAnalysis.action_verdict(Organization, onboard, nil) == :never
      assert PolicyAnalysis.action_verdict(Organization, onboard, %User{admin: true}) == :always
    end
  end
end
