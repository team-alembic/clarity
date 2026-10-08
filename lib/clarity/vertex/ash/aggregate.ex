with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Aggregate do
    @moduledoc """
    Vertex implementation for Ash resource aggregates.
    """
    alias Ash.Resource.Aggregate
    alias Ash.Resource.Info
    alias Clarity.SourceLocation
    alias Clarity.Vertex.HintProvider

    @type t() :: %__MODULE__{
            aggregate: Aggregate.t(),
            resource: Ash.Resource.t()
          }
    @enforce_keys [:aggregate, :resource]
    defstruct [:aggregate, :resource]

    @doc """
    The type of an aggregate's value. Ash leaves the aggregate's `type` unset
    when it follows from the kind and field (a `count` is an integer), so this
    asks Ash to work it out, falling back to `type`.
    """
    @spec value_type(Ash.Resource.t(), Aggregate.t()) :: Ash.Type.t() | nil
    def value_type(resource, aggregate) do
      case Info.aggregate_type(resource, aggregate) do
        {:ok, type} -> type
        _error -> aggregate.type
      end
    end

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{aggregate: %{name: name}, resource: resource}),
        do: Util.id(@for, [resource, name])

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Aggregate)

      @impl Clarity.Vertex
      def name(%@for{aggregate: %{name: name}}), do: Atom.to_string(name)
    end

    defimpl Clarity.Vertex.GraphGroupProvider do
      @impl Clarity.Vertex.GraphGroupProvider
      def graph_group(%@for{resource: resource}), do: [inspect(resource), inspect(Aggregate)]
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "Mdiamond"
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%@for{aggregate: aggregate, resource: resource}) do
        SourceLocation.from_spark_entity(resource, aggregate)
      end
    end

    defimpl Clarity.Vertex.HintProvider do
      @impl HintProvider
      def icon(_vertex), do: :aggregate

      @impl HintProvider
      def badges(%@for{aggregate: aggregate}), do: if(aggregate.public?, do: ["public"], else: [])

      @impl HintProvider
      def facts(%@for{aggregate: aggregate, resource: resource}) do
        [{"Resource", inspect(resource)}, {"Kind", Atom.to_string(aggregate.kind)}] ++
          case aggregate.relationship_path do
            [] -> []
            path -> [{"Path", Enum.join(path, ".")}]
          end ++
          if(aggregate.field, do: [{"Field", to_string(aggregate.field)}], else: [])
      end
    end
  end
end
