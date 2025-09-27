case Code.ensure_loaded(Ash) do
  {:module, Ash} ->
    defmodule Clarity.Introspector.Ash.Resource do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Ash.Domain.Info
      alias Clarity.Vertex.Ash.Domain
      alias Clarity.Vertex.Ash.Resource

      @impl Clarity.Introspector
      def source_vertex_types, do: [Domain]

      @impl Clarity.Introspector
      def introspect_vertex(%Domain{domain: domain} = domain_vertex, _graph) do
        Enum.flat_map(Info.resources(domain), fn resource ->
          resource_vertex = %Resource{resource: resource}

          [
            {:vertex, resource_vertex},
            {:edge, domain_vertex, resource_vertex, :resource}
            | Clarity.Introspector.moduledoc_content(resource, resource_vertex)
          ]
        end)
      end

      def introspect_vertex(_vertex, _graph), do: []
    end

  _ ->
    defmodule Clarity.Introspector.Ash.Resource do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: []

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: []
    end
end
