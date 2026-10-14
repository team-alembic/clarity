with {:module, Ash.Signals} <- Code.ensure_loaded(Ash.Signals) do
  defmodule Clarity.Status.SignalIntegrity do
    @moduledoc """
    Flags Ash signal problems in the `:integrity` status class.

    - `:error` on a resource when Ash's signal verifiers reject an `emit` or
      a listener. Spark gives only a compile warning for these, so the
      resource still loads.
    - `:info` on a signal that has no listener, or that no action emits.

    A verifier stops at its first error, so a resource shows at most one
    error from each verifier. The results are kept until the code of the
    resource or of one of its signal modules changes.
    """

    @behaviour Clarity.Status.Provider

    alias Ash.Resource.Info
    alias Ash.Resource.Verifiers.VerifyEmitSignal
    alias Ash.Resource.Verifiers.VerifySignalListeners
    alias Clarity.Graph
    alias Clarity.ModuleCache
    alias Clarity.Status
    alias Clarity.Status.Provider
    alias Clarity.Vertex.Ash.Resource
    alias Clarity.Vertex.Ash.Signal
    alias Spark.Error.DslError

    @verifiers [VerifyEmitSignal, VerifySignalListeners]

    @impl Provider
    def statuses(%Resource{resource: resource}, _graph) do
      case signal_modules(resource) do
        [] ->
          []

        modules ->
          ModuleCache.fetch({__MODULE__, resource}, [resource | modules], fn ->
            Enum.flat_map(@verifiers, &verify(&1, resource))
          end)
      end
    end

    def statuses(%Signal{} = vertex, graph) do
      whole = Graph.unfiltered(graph)

      for {true, message} <- [
            {Graph.out_degree(whole, vertex, :triggers) == 0, "No listener"},
            {Graph.in_degree(whole, vertex, :emits) == 0, "No action emits this signal"}
          ],
          do: status(:info, message)
    end

    def statuses(_vertex, _graph), do: []

    @spec signal_modules(Ash.Resource.t()) :: [module()]
    defp signal_modules(resource) do
      listened = for listener <- Info.signal_listeners(resource), do: listener.signal_module
      Enum.uniq(Info.signals_out(resource) ++ listened)
    rescue
      _error -> []
    end

    @spec verify(module(), Ash.Resource.t()) :: [Status.t()]
    defp verify(verifier, resource) do
      case verifier.verify(resource.spark_dsl_config()) do
        {:error, %DslError{} = error} -> [error_status(error)]
        _ok -> []
      end
    rescue
      error in DslError -> [error_status(error)]
      _error -> []
    end

    @spec error_status(Exception.t()) :: Status.t()
    defp error_status(%DslError{path: [_ | _] = path, message: message}),
      do: status(:error, Enum.map_join(path, " -> ", &segment/1) <> ": " <> to_string(message))

    defp error_status(%DslError{message: message}), do: status(:error, to_string(message))

    @spec segment(term()) :: String.t()
    defp segment(part) when is_atom(part), do: part |> inspect() |> String.trim_leading(":")
    defp segment(part), do: to_string(part)

    @spec status(Status.severity(), String.t()) :: Status.t()
    defp status(severity, message),
      do: %Status{severity: severity, class: :integrity, message: message, source: __MODULE__}
  end
end
