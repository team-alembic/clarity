with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.StateMachineDiagram do
    @moduledoc """
    D2 state diagram for an Ash resource that uses the AshStateMachine
    extension.

    Each state is rendered as an oval; transitions are edges labelled
    with the action that drives them. Initial states are highlighted
    green, terminal states (default initial / unset) red. Edges
    aggregate when the same `(from, to)` pair has multiple actions —
    the action names are concatenated with `, ` in the label.

    The provider is hidden for resources that do not declare
    `state_machine` blocks (i.e. don't use AshStateMachine), so it
    appears only where it is meaningful.
    """

    @behaviour Clarity.Content

    alias Clarity.Content.D2.Helpers
    alias Clarity.Vertex.Ash.Resource

    @impl Clarity.Content
    def name, do: "State Machine"

    @impl Clarity.Content
    def description, do: "AshStateMachine state diagram for this resource"

    @impl Clarity.Content
    def sort_priority, do: -60

    @impl Clarity.Content
    def applies?(%Resource{resource: resource}, _lens) do
      with {:module, info_module} <- Code.ensure_loaded(AshStateMachine.Info),
           true <- function_exported?(info_module, :transitions, 1),
           transitions when transitions != [] <- info_module.transitions(resource) do
        true
      else
        _ -> false
      end
    end

    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Resource{resource: resource}, _lens) do
      {:d2, fn _props -> to_d2(resource) end}
    end

    @spec to_d2(Ash.Resource.t()) :: iodata()
    defp to_d2(resource) do
      info = state_machine_info_module()
      transitions = info.transitions(resource)
      initials = safe_call(info, :initial_states, [resource], [])
      defaults = safe_call(info, :default_initial_state, [resource], nil)
      all_states = safe_call(info, :all_states, [resource], collect_states(transitions))

      initial_set =
        (initials || [defaults]) |> List.wrap() |> Enum.reject(&is_nil/1) |> MapSet.new()

      grouped = group_transitions(transitions)

      [
        "direction: right\n",
        Enum.map(all_states, &state_node(&1, initial_set)),
        Enum.map(grouped, &transition_edge/1)
      ]
    end

    @spec collect_states([map()]) :: [atom()]
    defp collect_states(transitions) do
      transitions
      |> Enum.flat_map(fn transition ->
        List.wrap(Map.get(transition, :from)) ++ List.wrap(Map.get(transition, :to))
      end)
      |> Enum.uniq()
    end

    @spec group_transitions([map()]) :: [{{atom(), atom()}, [atom()]}]
    defp group_transitions(transitions) do
      transitions
      |> Enum.flat_map(fn transition ->
        froms = List.wrap(Map.get(transition, :from))
        tos = List.wrap(Map.get(transition, :to))
        action = Map.get(transition, :action)

        for from <- froms, to <- tos, do: {{from, to}, action}
      end)
      |> Enum.group_by(fn {pair, _action} -> pair end, fn {_pair, action} -> action end)
      |> Enum.map(fn {pair, actions} -> {pair, Enum.uniq(actions)} end)
    end

    @spec state_node(atom(), MapSet.t()) :: iodata()
    defp state_node(state, initial_set) do
      id = Helpers.safe_id(Atom.to_string(state))

      style =
        if MapSet.member?(initial_set, state) do
          "  style: { fill: \"#dcfce7\"; stroke: \"#15803d\" }\n"
        else
          []
        end

      [
        id,
        ": ",
        Helpers.quoted(Atom.to_string(state)),
        " {\n",
        "  shape: oval\n",
        style,
        "}\n"
      ]
    end

    @spec transition_edge({{atom(), atom()}, [atom()]}) :: iodata()
    defp transition_edge({{from, to}, actions}) do
      src = Helpers.safe_id(Atom.to_string(from))
      dst = Helpers.safe_id(Atom.to_string(to))

      label = Enum.map_join(actions, ", ", &Atom.to_string/1)

      [src, " -> ", dst, ": ", Helpers.quoted(label), "\n"]
    end

    @spec safe_call(module(), atom(), [term()], term()) :: term()
    defp safe_call(module, fun, args, default) do
      arity = length(args)

      if function_exported?(module, fun, arity) do
        apply(module, fun, args)
      else
        default
      end
    rescue
      _ -> default
    end

    # Resolved at runtime so credo's apply/3-with-known-arity check is happy
    # and so the module reference doesn't fail at compile time when
    # AshStateMachine is not a dependency.
    @spec state_machine_info_module() :: module()
    defp state_machine_info_module, do: Module.safe_concat([AshStateMachine, Info])
  end
end
