if Code.ensure_loaded?(Reactor) do
  defimpl Clarity.Vertex, for: Reactor do
    def unique_id(reactor), do: "reactor:#{inspect(reactor.id)}"
    def graph_id(reactor), do: inspect(reactor.id)
    def graph_group(_), do: ["Reactor"]
    def type_label(_), do: "Reactor"
    def dot_shape(_), do: "cds"

    def render_name(reactor) do
      with <<"Elixir." <> _>> <- to_string(reactor.id) do
        inspect(reactor.id)
      end
    end

    def markdown_overview(reactor) do
      [
        "Reactor: `",
        inspect(reactor.id),
        "`\n\n",
        case reactor do
          %{description: description} when byte_size(description) > 0 ->
            [reactor.description, "\n\n"]

          _ ->
            []
        end,
        case reactor.inputs do
          [] ->
            []

          inputs ->
            [
              "## Inputs\n",
              Enum.map(
                inputs,
                fn input ->
                  [
                    "- `",
                    inspect(input),
                    "`",
                    if reactor.input_descriptions[input] do
                      [":", reactor.input_descriptions[input]]
                    else
                      []
                    end,
                    "\n"
                  ]
                end
              ),
              "\n"
            ]
        end,
        "## Returns\n",
        "  - The result of the `",
        inspect(reactor.return),
        "` step.\n\n"
      ]
    end
  end
end
