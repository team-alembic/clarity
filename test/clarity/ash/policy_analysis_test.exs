defmodule Clarity.Ash.PolicyAnalysisTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Ash.DataLayer.Ets
  alias Ash.Policy.Authorizer
  alias Ash.Policy.Check
  alias Ash.Policy.SimpleCheck
  alias Ash.Resource.Info
  alias Clarity.Ash.PolicyAnalysis
  alias Clarity.Graph
  alias Clarity.Report.SecurityPosture
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
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
      data_layer: Ets,
      authorizers: [Authorizer]

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

  defmodule ChangesetActorCheck do
    @moduledoc false
    use SimpleCheck

    @impl Check
    def describe(_opts), do: "matches a changeset with an actor"

    # No catch-all clause, as hosts often write it.
    @impl SimpleCheck
    def match?(%{id: _}, %{subject: %Ash.Changeset{}}, _opts), do: true
  end

  defmodule SpyCheck do
    @moduledoc false
    use SimpleCheck

    @impl Check
    def describe(_opts), do: "tells the test process it ran"

    @impl SimpleCheck
    def match?(_actor, _context, _opts) do
      send(self(), :spy_check_ran)
      true
    end
  end

  defmodule RaisingThing do
    @moduledoc false
    use Ash.Resource,
      domain: Domain,
      data_layer: Ets,
      authorizers: [Authorizer]

    attributes do
      uuid_primary_key :id
    end

    actions do
      defaults [:read, create: []]
    end

    policies do
      policy action_type(:read) do
        authorize_if Clarity.Ash.PolicyAnalysisTest.ChangesetActorCheck
      end

      policy action_type(:create) do
        authorize_if always()
      end
    end
  end

  defmodule SpiedThing do
    @moduledoc false
    use Ash.Resource,
      domain: Domain,
      data_layer: Ets,
      authorizers: [Authorizer]

    attributes do
      uuid_primary_key :id
    end

    actions do
      defaults [:read, create: []]
    end

    policies do
      policy action_type(:read) do
        authorize_if always()
      end

      policy action_type(:create) do
        authorize_if Clarity.Ash.PolicyAnalysisTest.SpyCheck
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

    test "is unknown, not a crash, when a policy check raises" do
      read = Info.action(RaisingThing, :read)

      assert PolicyAnalysis.action_verdict(RaisingThing, read, nil) == :unknown
    end

    test "does not log a warning or an error when a policy check raises" do
      read = Info.action(RaisingThing, :read)

      log =
        capture_log([level: :warning], fn ->
          assert PolicyAnalysis.action_verdict(RaisingThing, read, nil) == :unknown
        end)

      assert log == ""
    end

    test "skips the checks of a policy that does not apply to the action" do
      read = Info.action(SpiedThing, :read)
      create = Info.action(RaisingThing, :create)

      assert PolicyAnalysis.action_verdict(SpiedThing, read, nil) == :always
      refute_received :spy_check_ran

      assert PolicyAnalysis.action_verdict(RaisingThing, create, nil) == :always
    end

    test "runs the checks of a policy that applies to the action" do
      create = Info.action(SpiedThing, :create)

      assert PolicyAnalysis.action_verdict(SpiedThing, create, nil) == :always
      assert_received :spy_check_ran
    end
  end

  describe "the security posture report" do
    test "analyses a resource with a policy check that raises" do
      graph = Graph.new()
      Graph.add_vertex(graph, %Resource{resource: RaisingThing}, %Root{})

      assert %{resources: [%{reach: reach}]} = SecurityPosture.analyse(graph)
      assert is_map(reach)
      assert [_ | _] = SecurityPosture.actions(graph, [])
    end
  end
end
