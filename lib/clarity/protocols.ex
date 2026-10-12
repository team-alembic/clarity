defmodule Clarity.Protocols do
  @moduledoc false

  # Projects often leave protocols unconsolidated in development, for faster
  # recompiles. Then a protocol finds a type's implementation through the code
  # server on every call, and for a type without one, which falls back to
  # `Any`, the code server searches the whole code path for it each time.
  # Clarity calls these protocols for every vertex a page shows, and most
  # vertex types implement few of them, so it consolidates them itself.
  #
  # Only the protocols that fall back to `Any`: one that misses an
  # implementation added since (see consolidate_again/1) falls back, rather
  # than failing.

  @protocols [
    Clarity.Vertex.DetailProvider,
    Clarity.Vertex.GraphGroupProvider,
    Clarity.Vertex.GraphShapeProvider,
    Clarity.Vertex.HintProvider,
    Clarity.Vertex.ModuleProvider,
    Clarity.Vertex.SourceLocationProvider,
    Clarity.Vertex.TooltipProvider
  ]

  @consolidated {__MODULE__, :consolidated}

  @doc """
  Consolidates the protocols, unless the project has.
  """
  @spec consolidate() :: :ok
  def consolidate do
    unconsolidated = Enum.reject(@protocols, &consolidated?/1)

    if unconsolidated != [] do
      consolidate(unconsolidated)
      :persistent_term.put(@consolidated, true)
    end

    :ok
  end

  @doc """
  Consolidates the protocols again, if it did before and `modules` (compiled
  since) may implement one.
  """
  @spec consolidate_again([module()]) :: :ok
  def consolidate_again(modules) do
    if :persistent_term.get(@consolidated, false) and Enum.any?(modules, &implementation?/1),
      do: consolidate(@protocols)

    :ok
  end

  @doc """
  Whether `module` is named as an implementation of one of the protocols is.
  """
  @spec implementation?(module()) :: boolean()
  def implementation?(module) do
    name = Atom.to_string(module)
    Enum.any?(@protocols, &String.starts_with?(name, Atom.to_string(&1) <> "."))
  end

  @spec consolidated?(module()) :: boolean()
  defp consolidated?(protocol),
    do: Code.ensure_loaded?(protocol) and Protocol.consolidated?(protocol)

  @spec consolidate([module()]) :: :ok
  defp consolidate(protocols) do
    paths = :code.get_path()

    for protocol <- protocols,
        Code.ensure_loaded?(protocol),
        {:ok, binary} <- [Protocol.consolidate(protocol, Protocol.extract_impls(protocol, paths))],
        # Leaves the protocol as it is while something still runs its old code.
        :code.soft_purge(protocol) do
      :code.load_binary(protocol, :code.which(protocol), binary)
    end

    :ok
  end
end
