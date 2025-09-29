with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Action do
    @moduledoc false
    alias Ash.Resource.Actions
    alias Spark.Dsl.Entity

    @type t() :: %__MODULE__{
            action: Actions.action(),
            resource: Ash.Resource.t()
          }
    @enforce_keys [:action, :resource]
    defstruct [:action, :resource]

    defimpl Clarity.Vertex do
      @impl Clarity.Vertex
      def unique_id(%{action: %{name: name}, resource: resource}),
        do: "action:#{inspect(resource)}:#{name}"

      @impl Clarity.Vertex
      def graph_id(%{action: %{name: name}, resource: resource}),
        do: [inspect(resource), "_", Atom.to_string(name)]

      @impl Clarity.Vertex
      def graph_group(%{resource: resource}), do: [inspect(resource), inspect(Actions)]

      @impl Clarity.Vertex
      def type_label(%{action: %mod{}}), do: inspect(mod)

      @impl Clarity.Vertex
      def render_name(%{action: %{name: name}}), do: Atom.to_string(name)

      @impl Clarity.Vertex
      def dot_shape(_vertex), do: "cds"

      @impl Clarity.Vertex
      def markdown_overview(%{action: action, resource: resource}) do
        [
          "Action: `",
          inspect(action.name),
          "` on Resource: `",
          inspect(resource),
          "`\n\n",
          if action.description do
            [action.description, "\n\n"]
          else
            []
          end,
          case action.arguments do
            [] ->
              []

            args ->
              [
                "## Arguments\n",
                Enum.map(args, fn arg ->
                  [
                    "- `",
                    inspect(arg.name),
                    "` (`",
                    inspect(arg.type),
                    "`)",
                    if arg.description do
                      [
                        ": ",
                        arg.description
                      ]
                    else
                      []
                    end,
                    "\n"
                  ]
                end),
                "\n\n"
              ]
          end
        ]
      end

      @impl Clarity.Vertex
      def source_anno(%{action: action}), do: Entity.anno(action)
    end
  end
end
