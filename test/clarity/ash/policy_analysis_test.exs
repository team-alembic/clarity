defmodule Clarity.Ash.PolicyAnalysisTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Ash.PolicyAnalysis
  alias Demo.Accounts.Organization
  alias Demo.Accounts.User

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      allow_unregistered? true
    end
  end

  defmodule Thing do
    @moduledoc false
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]

      # Assumes `title` is given, so building it from empty input raises.
      create :create do
        argument :title, :string

        change fn changeset, _context ->
          title = Ash.Changeset.get_argument(changeset, :title)
          Ash.Changeset.change_attribute(changeset, :name, String.upcase(title))
        end
      end
    end

    policies do
      policy always() do
        authorize_if always()
      end
    end
  end

  describe inspect(&PolicyAnalysis.action_verdict/3) do
    # :onboard is a generic action (type :action), run by a Reactor. No policy
    # but the admin bypass covers it.
    test "analyses generic actions" do
      onboard = Info.action(Organization, :onboard)

      assert PolicyAnalysis.action_verdict(Organization, onboard, nil) == :never
      assert PolicyAnalysis.action_verdict(Organization, onboard, %User{admin: true}) == :always
    end

    test "is unknown for an action whose own code raises on empty input" do
      create = Info.action(Thing, :create)
      read = Info.action(Thing, :read)

      assert PolicyAnalysis.action_verdict(Thing, create, nil) == :unknown
      assert PolicyAnalysis.action_verdict(Thing, read, nil) == :always
    end
  end
end
