defmodule Clarity.Ash.PolicyAnalysisTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Ash.DataLayer.Ets
  alias Ash.Policy.Authorizer
  alias Ash.Policy.Check
  alias Ash.Policy.SimpleCheck
  alias Ash.Resource.Change
  alias Ash.Resource.Info
  alias Ash.Resource.Preparation
  alias Ash.Resource.Validation
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

  defmodule NotifyChange do
    @moduledoc false
    use Change

    @impl Change
    def change(changeset, _opts, _context) do
      send(self(), {:notified, :change})
      changeset
    end
  end

  defmodule NotifyPreparation do
    @moduledoc false
    use Preparation

    @impl Preparation
    def prepare(query, _opts, _context) do
      send(self(), {:notified, :preparation})
      query
    end
  end

  defmodule NotifyValidation do
    @moduledoc false
    use Validation

    @impl Validation
    def supports(_opts), do: [Ash.ActionInput, Ash.Changeset, Ash.Query]

    @impl Validation
    def validate(_subject, _opts, _context) do
      send(self(), {:notified, :validation})
      :ok
    end
  end

  defmodule NotifyingThing do
    @moduledoc false
    use Ash.Resource,
      domain: Domain,
      data_layer: Ets,
      authorizers: [Authorizer]

    alias Clarity.Ash.PolicyAnalysisTest.NotifyChange

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      read :read do
        prepare Clarity.Ash.PolicyAnalysisTest.NotifyPreparation
      end

      create :create do
        change NotifyChange
      end

      update :update do
        require_atomic? false
        change NotifyChange
      end

      destroy :destroy do
        require_atomic? false
        change NotifyChange
      end

      action :ping, :boolean do
        validate Clarity.Ash.PolicyAnalysisTest.NotifyValidation
        run fn _input, _context -> {:ok, true} end
      end
    end

    policies do
      policy always() do
        authorize_if always()
      end
    end
  end

  defmodule SubjectReadingThing do
    @moduledoc false
    use Ash.Resource,
      domain: Domain,
      data_layer: Ets,
      authorizers: [Authorizer]

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
      attribute :admin, :boolean, public?: true
    end

    actions do
      defaults [:read, create: [:name], update: [:name]]
    end

    policies do
      policy action_type(:read) do
        authorize_if actor_attribute_equals(:admin, true)
      end

      policy action_type(:create) do
        authorize_if changing_attributes(name: [to: "x"])
      end

      policy action_type(:update) do
        authorize_if Clarity.Ash.PolicyAnalysisTest.ChangesetActorCheck
      end
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

  defmodule ArgumentCheck do
    @moduledoc false
    use SimpleCheck

    @impl Check
    def describe(opts), do: "matches when argument #{opts[:name]} is #{inspect(opts[:value])}"

    @impl SimpleCheck
    def match?(_actor, %{subject: subject}, opts), do: Ash.Subject.get_argument(subject, opts[:name]) == opts[:value]
  end

  defmodule DefaultNotifier do
    @moduledoc false

    @spec stamp() :: integer()
    def stamp do
      send(self(), :default_ran)
      1
    end
  end

  defmodule DefaultingThing do
    @moduledoc false
    use Ash.Resource,
      domain: Domain,
      data_layer: Ets,
      authorizers: [Authorizer]

    alias Clarity.Ash.PolicyAnalysisTest.ArgumentCheck

    attributes do
      uuid_primary_key :id
      attribute :status, :string, default: "draft", update_default: "edited", public?: true
    end

    actions do
      create :flagged do
        argument :flag, :boolean, default: true
      end

      create :draft

      update :edit do
        require_atomic? false
      end

      read :search do
        argument :limit, :integer, default: 10
      end

      action :ping, :boolean do
        argument :loud, :boolean, default: true
        run fn _input, _context -> {:ok, true} end
      end
    end

    policies do
      policy action(:flagged) do
        authorize_if {ArgumentCheck, name: :flag, value: true}
      end

      policy action(:draft) do
        authorize_if changing_attributes(status: [to: "draft"])
      end

      policy action(:edit) do
        authorize_if changing_attributes(status: [to: "edited"])
      end

      policy action(:search) do
        authorize_if {ArgumentCheck, name: :limit, value: 10}
      end

      policy action(:ping) do
        authorize_if {ArgumentCheck, name: :loud, value: true}
      end
    end
  end

  defmodule FunctionDefaultingThing do
    @moduledoc false
    use Ash.Resource,
      domain: Domain,
      data_layer: Ets,
      authorizers: [Authorizer]

    alias Clarity.Ash.PolicyAnalysisTest.DefaultNotifier

    attributes do
      uuid_primary_key :id

      attribute :stamped, :integer,
        default: &DefaultNotifier.stamp/0,
        public?: true
    end

    actions do
      create :create do
        argument :stamp, :integer, default: &DefaultNotifier.stamp/0
      end
    end

    # :onboard is a generic action (type :action), run by a Reactor. No policy
    # but the admin bypass covers it.
    policies do
      policy always() do
        authorize_if {Clarity.Ash.PolicyAnalysisTest.ArgumentCheck, name: :stamp, value: nil}
      end
    end
  end

  describe inspect(&PolicyAnalysis.action_verdict/3) do
    test "analyses generic actions" do
      onboard = Info.action(Organization, :onboard)

      assert PolicyAnalysis.action_verdict(Organization, onboard, nil) == :never
      assert PolicyAnalysis.action_verdict(Organization, onboard, %User{admin: true}) == :always
    end

    test "analyses an action whose own code raises on empty input" do
      create = Info.action(Thing, :create)
      read = Info.action(Thing, :read)

      assert PolicyAnalysis.action_verdict(Thing, create, nil) == :always
      assert PolicyAnalysis.action_verdict(Thing, read, nil) == :always
    end

    test "does not run the changes of a create action" do
      create = Info.action(NotifyingThing, :create)

      assert PolicyAnalysis.action_verdict(NotifyingThing, create, nil) == :always
      refute_received {:notified, _}
    end

    test "does not run the changes of an update action" do
      update = Info.action(NotifyingThing, :update)

      assert PolicyAnalysis.action_verdict(NotifyingThing, update, nil) == :always
      refute_received {:notified, _}
    end

    test "does not run the changes of a destroy action" do
      destroy = Info.action(NotifyingThing, :destroy)

      assert PolicyAnalysis.action_verdict(NotifyingThing, destroy, nil) == :always
      refute_received {:notified, _}
    end

    test "does not run the preparations of a read action" do
      read = Info.action(NotifyingThing, :read)

      assert PolicyAnalysis.action_verdict(NotifyingThing, read, nil) == :always
      refute_received {:notified, _}
    end

    test "does not run the validations of a generic action" do
      ping = Info.action(NotifyingThing, :ping)

      assert PolicyAnalysis.action_verdict(NotifyingThing, ping, nil) == :always
      refute_received {:notified, _}
    end

    test "gives checks the actor, the action type and an empty changeset" do
      read = Info.action(SubjectReadingThing, :read)
      create = Info.action(SubjectReadingThing, :create)
      update = Info.action(SubjectReadingThing, :update)

      assert PolicyAnalysis.action_verdict(SubjectReadingThing, read, %{admin: true}) == :always
      assert PolicyAnalysis.action_verdict(SubjectReadingThing, read, %{admin: false}) == :never
      assert PolicyAnalysis.action_verdict(SubjectReadingThing, read, nil) == :never
      assert PolicyAnalysis.action_verdict(SubjectReadingThing, create, nil) == :never
      assert PolicyAnalysis.action_verdict(SubjectReadingThing, update, %{id: 1}) == :always
    end

    test "gives checks the static defaults of a create action's arguments" do
      flagged = Info.action(DefaultingThing, :flagged)

      assert PolicyAnalysis.action_verdict(DefaultingThing, flagged, nil) == :always
    end

    test "gives checks the static defaults of a read action's arguments" do
      search = Info.action(DefaultingThing, :search)

      assert PolicyAnalysis.action_verdict(DefaultingThing, search, nil) == :always
    end

    test "gives checks the static defaults of a generic action's arguments" do
      ping = Info.action(DefaultingThing, :ping)

      assert PolicyAnalysis.action_verdict(DefaultingThing, ping, nil) == :always
    end

    test "gives checks the static defaults of a create action's attributes" do
      draft = Info.action(DefaultingThing, :draft)

      assert PolicyAnalysis.action_verdict(DefaultingThing, draft, nil) == :always
    end

    test "gives checks the static update defaults of an update action's attributes" do
      edit = Info.action(DefaultingThing, :edit)

      assert PolicyAnalysis.action_verdict(DefaultingThing, edit, nil) == :always
    end

    test "does not run a function default" do
      create = Info.action(FunctionDefaultingThing, :create)

      assert PolicyAnalysis.action_verdict(FunctionDefaultingThing, create, nil) == :always
      refute_received :default_ran
    end

    test "is unknown, not a crash, when the subject cannot be built" do
      read = Info.action(Thing, :read)

      assert PolicyAnalysis.action_verdict(Thing, %{read | type: :not_a_type}, nil) == :unknown
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
