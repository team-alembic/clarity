case Code.ensure_loaded(Ash) do
  {:module, Ash} ->
    defmodule Clarity.Introspector.Ash.Domain do
      @moduledoc false

      @behaviour Clarity.Introspector

      alias Clarity.Vertex.Application
      alias Clarity.Vertex.Ash.Domain

      @impl Clarity.Introspector
      def source_vertex_types, do: [Application]

      @impl Clarity.Introspector
      def introspect_vertex(%Application{app: app} = app_vertex, _graph) do
        Enum.flat_map(Ash.Info.domains(app), fn domain ->
          domain_vertex = %Domain{domain: domain}

          [
            {:vertex, domain_vertex},
            {:edge, app_vertex, domain_vertex, :domain}
            | Clarity.Introspector.moduledoc_content(domain, domain_vertex)
          ]
        end)
      end

      def introspect_vertex(_vertex, _graph), do: []
    end

  _ ->
    defmodule Clarity.Introspector.Ash.Domain do
      @moduledoc false

      @behaviour Clarity.Introspector

      @impl Clarity.Introspector
      def source_vertex_types, do: []

      @impl Clarity.Introspector
      def introspect_vertex(_vertex, _graph), do: []
    end
end
