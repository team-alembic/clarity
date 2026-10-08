with {:module, Reactor} <- Code.ensure_loaded(Reactor) do
  defmodule Clarity.Content.Reactor.FlowDiagram do
    @moduledoc """
    Content provider that draws a Reactor as a Mermaid flowchart.

    It shows the Reactor's inputs and its steps, each with its description,
    joined by edges labelled with the argument they fill. A `switch` is a
    decision with a subgraph per branch, and every branch's returning step
    feeds the steps that use the switch's result. Steps that can undo or
    compensate say so, and the step whose result the Reactor returns is
    outlined. The tab shows on the Reactor and on any Ash generic action that
    runs it.
    """

    @behaviour Clarity.Content

    alias Clarity.Vertex
    alias Reactor.Step
    alias Reactor.Template

    @impl Clarity.Content
    def name, do: "Reactor Flow"

    @impl Clarity.Content
    def description, do: "The Reactor's inputs and steps, and the arguments that join them"

    @impl Clarity.Content
    def sort_priority, do: -50

    @impl Clarity.Content
    def applies?(vertex, _lens), do: reactor(vertex) != nil

    @impl Clarity.Content
    def render_static(vertex, _lens) do
      reactor = reactor(vertex)
      {:mermaid, fn _props -> diagram(reactor) end}
    end

    # Matched by struct name, so this compiles where Reactor is used without Ash.
    @spec reactor(Vertex.t()) :: module() | nil
    defp reactor(%Vertex.Reactor{reactor: reactor}), do: reactor

    defp reactor(%{__struct__: Vertex.Ash.Action, action: action}),
      do: Vertex.Reactor.run_by(action)

    defp reactor(_vertex), do: nil

    @spec diagram(module()) :: iodata()
    defp diagram(module) do
      reactor = Reactor.Info.to_struct!(module)
      # The planned Reactor holds its inputs and steps last defined first.
      steps = Enum.reverse(reactor.steps)
      producers = producers(steps, %{})

      [
        "flowchart LR\n",
        "  classDef returned stroke:#16a34a,stroke-width:3px;\n",
        reactor.inputs |> Enum.reverse() |> Enum.map(&input_node/1),
        Enum.map(steps, &step_nodes(&1, "  ")),
        Enum.map(steps, &step_edges(&1, producers)),
        Enum.map(Map.get(producers, reactor.return, []), &["  class ", &1, " returned\n"])
      ]
    end

    # Maps each step's name to the nodes its result comes from: the step
    # itself, or for a switch, the steps its branches return.
    @spec producers([Step.t()], map()) :: %{atom() => [String.t()]}
    defp producers(steps, acc) do
      Enum.reduce(steps, acc, fn step, acc ->
        case branches(step) do
          [] -> Map.put(acc, step.name, [step_id(step.name)])
          branches -> switch_producers(step, branches, acc)
        end
      end)
    end

    @spec switch_producers(Step.t(), [branch()], map()) :: %{atom() => [String.t()]}
    defp switch_producers(switch, branches, acc) do
      acc =
        Enum.reduce(branches, acc, fn {_id, _title, steps, _return}, acc ->
          producers(steps, acc)
        end)

      returned =
        Enum.flat_map(branches, fn {_id, _title, _steps, return} -> Map.get(acc, return, []) end)

      Map.put(acc, switch.name, Enum.uniq(returned))
    end

    # A switch's branches as `{subgraph id, title, steps, returned step name}`,
    # or `[]` for any other step. Each branch ends in a step named after the
    # switch that returns the branch's result; it's drawn as the edge out.
    @typep branch() :: {String.t(), String.t(), [Step.t()], atom() | nil}

    @spec branches(Step.t()) :: [branch()]
    defp branches(%{impl: {Step.Switch, options}} = switch) do
      matches =
        options
        |> Keyword.get(:matches, [])
        |> Enum.with_index(1)
        |> Enum.map(fn {{_predicate, steps}, index} ->
          {"match_#{index}", "match #{index}", steps}
        end)

      default =
        case Keyword.get(options, :default) do
          steps when steps in [nil, []] -> []
          steps -> [{"default", "default", steps}]
        end

      for {suffix, title, steps} <- matches ++ default do
        {returns, steps} = steps |> Enum.reverse() |> Enum.split_with(&(&1.name == switch.name))
        {step_id(switch.name) <> "_" <> suffix, title, steps, returned(returns)}
      end
    end

    defp branches(_step), do: []

    @spec returned([Step.t()]) :: atom() | nil
    defp returned([%{arguments: [%{source: %Template.Result{name: name}} | _]} | _]), do: name
    defp returned(_returns), do: nil

    @spec input_node(Reactor.Input.t() | atom()) :: iodata()
    defp input_node(%Reactor.Input{name: name, description: description}),
      do: ["  ", input_id(name), ">\"", label([bold(name), description]), "\"]\n"]

    defp input_node(name) when is_atom(name), do: input_node(%Reactor.Input{name: name})

    @spec step_nodes(Step.t(), String.t()) :: iodata()
    defp step_nodes(step, indent) do
      case branches(step) do
        [] ->
          [indent, step_id(step.name), "[\"", label(step_lines(step)), "\"]\n"]

        branches ->
          [
            indent,
            step_id(step.name),
            "{\"",
            label([bold(step.name), step.description]),
            "\"}\n",
            Enum.map(branches, fn {id, title, steps, _return} ->
              [
                indent,
                "subgraph ",
                id,
                " [\"",
                title,
                "\"]\n",
                indent,
                "  direction LR\n",
                Enum.map(steps, &step_nodes(&1, indent <> "  ")),
                indent,
                "end\n"
              ]
            end)
          ]
      end
    end

    @spec step_lines(Step.t()) :: [line()]
    defp step_lines(step) do
      markers =
        for {capability, marker} <- [undo: "↩ undo", compensate: "⟲ compensate"],
            Step.can?(step, capability),
            do: marker

      [bold(step.name), step.description, implementation(step), Enum.join(markers, " · ")]
    end

    @spec implementation(Step.t()) :: line()
    defp implementation(%{impl: {Step.AnonFn, _options}}), do: nil
    defp implementation(%{impl: {module, _options}}), do: italic(inspect(module))
    defp implementation(%{impl: module}) when is_atom(module), do: italic(inspect(module))

    @spec step_edges(Step.t(), map()) :: iodata()
    defp step_edges(step, producers) do
      case branches(step) do
        [] ->
          Enum.map(step.arguments, &argument_edges(&1, step_id(step.name), producers))

        branches ->
          # The switch's only argument is the value it matches on.
          [
            Enum.map(
              step.arguments,
              &argument_edges(%{&1 | name: nil}, step_id(step.name), producers)
            ),
            Enum.map(branches, fn {id, _title, _steps, _return} ->
              ["  ", step_id(step.name), " --> ", id, "\n"]
            end),
            Enum.map(branches, fn {_id, _title, steps, _return} ->
              Enum.map(steps, &step_edges(&1, producers))
            end)
          ]
      end
    end

    @spec argument_edges(map(), String.t(), map()) :: iodata()
    defp argument_edges(%{source: %Template.Input{name: input}} = argument, to, _producers),
      do: edge(input_id(input), to, argument.name)

    defp argument_edges(%{source: %Template.Result{name: result}} = argument, to, producers) do
      producers |> Map.get(result, []) |> Enum.map(&edge(&1, to, argument.name))
    end

    defp argument_edges(_argument, _to, _producers), do: []

    @spec edge(String.t(), String.t(), atom() | nil) :: iodata()
    defp edge(from, to, nil), do: ["  ", from, " --> ", to, "\n"]
    defp edge(from, to, name), do: ["  ", from, " -->|", Atom.to_string(name), "| ", to, "\n"]

    @spec input_id(atom()) :: String.t()
    defp input_id(name), do: "input_" <> safe(name)

    @spec step_id(atom()) :: String.t()
    defp step_id(name), do: "step_" <> safe(name)

    @spec safe(atom()) :: String.t()
    defp safe(name), do: String.replace(Atom.to_string(name), ~r/\W/u, "_")

    # A line of a node's label: markup, text to escape, or nothing.
    @typep line() :: {:html, iodata()} | String.t() | nil

    @spec bold(atom()) :: line()
    defp bold(name), do: {:html, ["<b>", escape(Atom.to_string(name)), "</b>"]}

    @spec italic(String.t()) :: line()
    defp italic(text), do: {:html, ["<i>", escape(text), "</i>"]}

    # Joins a node's lines with <br/>, leaving out blank ones, and escapes
    # text so quotes and angle brackets can't break the label.
    @spec label([line()]) :: iodata()
    defp label(lines) do
      lines
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.map_intersperse("<br/>", fn
        {:html, html} -> html
        text -> escape(text)
      end)
    end

    @spec escape(String.t()) :: String.t()
    defp escape(text) do
      text
      |> String.replace("\"", "#quot;")
      |> String.replace("<", "#lt;")
      |> String.replace(">", "#gt;")
      |> String.replace(~r/\s*\n\s*/, " ")
      |> String.trim()
    end
  end
end
