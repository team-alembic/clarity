with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Action do
    @moduledoc """
    Vertex implementation for Ash resource actions.
    """
    alias Ash.Resource.Actions
    alias Clarity.SourceLocation

    @type t() :: %__MODULE__{
            action: Actions.action(),
            resource: Ash.Resource.t()
          }
    @enforce_keys [:action, :resource]
    defstruct [:action, :resource]

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{action: %{name: name}, resource: resource}),
        do: Util.id(@for, [resource, name])

      @impl Clarity.Vertex
      def type_label(%@for{action: %mod{}}), do: inspect(mod)

      @impl Clarity.Vertex
      def name(%@for{action: %{name: name}}), do: Atom.to_string(name)
    end

    defimpl Clarity.Vertex.GraphGroupProvider do
      @impl Clarity.Vertex.GraphGroupProvider
      def graph_group(%@for{resource: resource}), do: [inspect(resource), inspect(Actions)]
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "cds"
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%{action: action, resource: resource}) do
        SourceLocation.from_spark_entity(resource, action)
      end
    end

    defimpl Clarity.Vertex.TooltipProvider do
      @impl Clarity.Vertex.TooltipProvider
      def tooltip(%@for{action: action, resource: resource}) do
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
    end
  end
end
