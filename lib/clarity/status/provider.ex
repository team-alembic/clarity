defmodule Clarity.Status.Provider do
  @moduledoc """
  Behaviour for modules that flag vertices with `Clarity.Status` indicators.

  Providers are registered per-application under `:clarity_status_providers`,
  the same mechanism as content providers:

      config :my_app, :clarity_status_providers, [MyApp.LicenceStatus]

  A provider returns the statuses for a single vertex and is lens-agnostic —
  lenses decide which status `class`es they surface. Return `[]` for vertices the
  provider has nothing to say about.

  ## Example

      defmodule MyApp.LicenceStatus do
        @behaviour Clarity.Status.Provider

        @impl Clarity.Status.Provider
        def statuses(%Clarity.Vertex.Application{} = vertex, _graph) do
          if non_compliant?(vertex) do
            [
              %Clarity.Status{
                severity: :warning,
                class: :licence,
                message: "Non-compliant licence",
                source: __MODULE__
              }
            ]
          else
            []
          end
        end

        def statuses(_vertex, _graph), do: []
      end
  """

  @callback statuses(vertex :: Clarity.Vertex.t(), graph :: Clarity.Graph.t()) ::
              [Clarity.Status.t()]

  @doc """
  What the provider's statuses depend on besides the graph, such as data it
  fetches in the background: any term that changes when that does.

  Statuses are worked out again when the graph changes. A provider whose
  statuses can change while the graph doesn't implements this, so they're
  worked out again when it changes too.
  """
  @callback version() :: term()

  @optional_callbacks version: 0
end
