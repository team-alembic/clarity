defmodule Clarity.Introspector.Advisory do
  @moduledoc """
  Links each `Application` vertex to the security advisories affecting its
  installed version, sourced from `Clarity.Advisory.Source`.

  Advisory data arrives asynchronously on a timer. Until the first refresh has
  populated the cache, this returns `{:error, :unmet_dependencies}` so the worker
  retries; the source triggers a re-introspection once data is available.
  """

  @behaviour Clarity.Introspector

  alias Clarity.Advisory.Source
  alias Clarity.Vertex

  @impl Clarity.Introspector
  def source_vertex_types, do: [Vertex.Application]

  @impl Clarity.Introspector
  def introspect_vertex(%Vertex.Application{} = app_vertex, _graph) do
    if Source.ready?() do
      entries =
        app_vertex.app
        |> Source.advisories_for(app_vertex.version)
        |> Enum.flat_map(&advisory_entries(&1, app_vertex))

      {:ok, entries}
    else
      {:error, :unmet_dependencies}
    end
  end

  def introspect_vertex(_vertex, _graph), do: {:ok, []}

  @spec advisory_entries(Clarity.Advisory.t(), Vertex.Application.t()) ::
          [Clarity.Introspector.entry()]
  defp advisory_entries(advisory, app_vertex) do
    advisory_vertex = %Vertex.Advisory{advisory: advisory}

    [
      {:vertex, advisory_vertex},
      {:edge, app_vertex, advisory_vertex, :advisory}
    ]
  end
end
