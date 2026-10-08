with {:module, AshStateMachine} <- Code.ensure_loaded(AshStateMachine) do
  defmodule Clarity.Content.Ash.StateMachineDiagram do
    @moduledoc """
    Content provider that draws an `AshStateMachine` resource as a Mermaid
    state diagram.

    Each state is a node, and each transition an edge labelled with the action
    that makes it. The diagram enters at the resource's initial states and
    leaves from its final states, those no transition leads out of.
    """

    @behaviour Clarity.Content

    alias AshStateMachine.Info
    alias Clarity.Vertex.Ash.Resource

    @impl Clarity.Content
    def name, do: "State Machine"

    @impl Clarity.Content
    def description, do: "The resource's states and the actions that move between them"

    @impl Clarity.Content
    def sort_priority, do: -50

    @impl Clarity.Content
    def applies?(%Resource{resource: resource}, _lens),
      do: AshStateMachine in Ash.Resource.Info.extensions(resource)

    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Resource{resource: resource}, _lens) do
      {:mermaid, fn _props -> diagram(resource) end}
    end

    @spec diagram(Ash.Resource.t()) :: iodata()
    defp diagram(resource) do
      states = Info.state_machine_all_states(resource)
      edges = edges(resource)
      left = MapSet.new(edges, fn {from, _to, _action} -> from end)

      [
        "stateDiagram-v2\n",
        "  direction LR\n",
        Enum.map(states, &["  state \"", label(&1), "\" as ", id(&1), "\n"]),
        Enum.map(Info.state_machine_initial_states!(resource), &["  [*] --> ", id(&1), "\n"]),
        Enum.map(edges, &edge/1),
        for(state <- states, not MapSet.member?(left, state), do: ["  ", id(state), " --> [*]\n"])
      ]
    end

    # One edge per pair of states a transition joins; ash_state_machine has
    # already expanded `:*` in `from` and `to` to every state.
    @spec edges(Ash.Resource.t()) :: [{atom(), atom(), atom()}]
    defp edges(resource) do
      for transition <- Info.state_machine_transitions(resource),
          from <- List.wrap(transition.from),
          to <- List.wrap(transition.to),
          do: {from, to, transition.action}
    end

    @spec edge({atom(), atom(), atom()}) :: iodata()
    defp edge({from, to, :*}), do: ["  ", id(from), " --> ", id(to), "\n"]

    defp edge({from, to, action}),
      do: ["  ", id(from), " --> ", id(to), " : ", Atom.to_string(action), "\n"]

    # Prefixed, so a state named after a Mermaid keyword (`end`, `state`,
    # `note`) can't break the diagram; the `state` lines show the real name.
    @spec id(atom()) :: String.t()
    defp id(state), do: "s_" <> String.replace(Atom.to_string(state), ~r/\W/u, "_")

    @spec label(atom()) :: String.t()
    defp label(state), do: state |> Atom.to_string() |> String.replace("\"", "#quot;")
  end
end
