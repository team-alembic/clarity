with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Vertex.Ash.Aggregate do
    @moduledoc false
    alias Ash.Resource.Aggregate
    alias Spark.Dsl.Entity

    @type t() :: %__MODULE__{
            aggregate: Aggregate.t(),
            resource: Ash.Resource.t()
          }
    @enforce_keys [:aggregate, :resource]
    defstruct [:aggregate, :resource]

    defimpl Clarity.Vertex do
      @impl Clarity.Vertex
      def unique_id(%{aggregate: %{name: name}, resource: resource}),
        do: "aggregate:#{inspect(resource)}:#{name}"

      @impl Clarity.Vertex
      def graph_id(%{aggregate: %{name: name}, resource: resource}),
        do: [inspect(resource), "_", Atom.to_string(name)]

      @impl Clarity.Vertex
      def graph_group(%{resource: resource}), do: [inspect(resource), inspect(Aggregate)]

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Aggregate)

      @impl Clarity.Vertex
      def render_name(%{aggregate: %{name: name}}), do: Atom.to_string(name)

      @impl Clarity.Vertex
      def dot_shape(_vertex), do: "Mdiamond"

      @impl Clarity.Vertex
      def markdown_overview(_vertex), do: []

      @impl Clarity.Vertex
      def source_anno(%{aggregate: aggregate}), do: Entity.anno(aggregate)
    end
  end
end
