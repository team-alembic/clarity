with {:module, Ash.Signals} <- Code.ensure_loaded(Ash.Signals) do
  defmodule Clarity.Vertex.Ash.SignalModule do
    @moduledoc """
    Vertex for a module that uses `Ash.Signals`.
    """

    alias Clarity.SourceLocation
    alias Clarity.Vertex.HintProvider
    alias Clarity.Vertex.Name

    @type t() :: %__MODULE__{signal_module: module()}
    @enforce_keys [:signal_module]
    defstruct [:signal_module]

    @doc "Returns whether the module uses `Ash.Signals`."
    @spec signal_module?(module()) :: boolean()
    def signal_module?(module) do
      Code.ensure_loaded?(module) and function_exported?(module, :spark_is, 0) and
        module.spark_is() == Ash.Signals
    end

    @doc """
    Returns the signal modules of an application, sorted by name. It loads
    only the modules that have an `Ash.Signals.Index` marker module, which
    Ash generates for each signal module.
    """
    @spec in_app(Application.app() | nil) :: [module()]
    def in_app(nil), do: []

    def in_app(app) do
      modules = Application.spec(app, :modules) || []

      marked =
        for module <- modules,
            "Elixir.Ash.Signals.Index." <> name <- [Atom.to_string(module)],
            into: MapSet.new(),
            do: "Elixir." <> name

      modules
      |> Enum.filter(&(MapSet.member?(marked, Atom.to_string(&1)) and signal_module?(&1)))
      |> Enum.sort_by(&inspect/1)
    end

    @doc """
    Returns the domain of the module's application that the module is nested
    under, or `nil`. Ash itself puts a signal module in no domain.
    """
    @spec domain(module()) :: module() | nil
    def domain(signal_module) do
      case Clarity.Config.application_of(signal_module) do
        nil -> nil
        app -> Name.nested_under(signal_module, Ash.Info.domains(app))
      end
    end

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{signal_module: module}), do: Util.id(@for, [module])

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Ash.Signals)

      @impl Clarity.Vertex
      def name(%@for{signal_module: module}), do: inspect(module)
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "folder"
    end

    defimpl Clarity.Vertex.ModuleProvider do
      @impl Clarity.Vertex.ModuleProvider
      def module(%@for{signal_module: module}), do: module
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%@for{signal_module: module}), do: SourceLocation.from_module(module)
    end

    defimpl Clarity.Vertex.TooltipProvider do
      @impl Clarity.Vertex.TooltipProvider
      def tooltip(%@for{signal_module: module}) do
        ["`", inspect(module), "`\n\n", Clarity.Docs.moduledoc(module) || []]
      end
    end

    defimpl Clarity.Vertex.HintProvider do
      @impl HintProvider
      def icon(_vertex), do: :signal_module

      @impl HintProvider
      def badges(_vertex), do: []

      @impl HintProvider
      def facts(%@for{signal_module: module}) do
        [{"Signals", module |> Ash.Signals.Info.signals() |> Enum.map(&Atom.to_string(&1.name))}]
      end
    end
  end
end
