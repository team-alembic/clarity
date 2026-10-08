with {:module, Reactor} <- Code.ensure_loaded(Reactor) do
  defmodule Clarity.Vertex.Reactor do
    @moduledoc """
    Vertex implementation for Reactors: modules that `use Reactor` to define a
    workflow of steps.
    """

    alias Clarity.SourceLocation
    alias Clarity.Vertex.HintProvider

    @type t() :: %__MODULE__{
            reactor: module()
          }
    @enforce_keys [:reactor]
    defstruct [:reactor]

    @doc """
    Returns whether `module` is a Reactor, one that `use`s `Reactor`.
    """
    @spec reactor?(module()) :: boolean()
    def reactor?(module) do
      Code.ensure_loaded?(module) and function_exported?(module, :spark_is, 0) and
        module.spark_is() == Reactor
    end

    @doc """
    Returns the Reactor an Ash generic action runs, or `nil` if it runs none.
    """
    @spec run_by(action :: struct()) :: module() | nil
    def run_by(%{type: :action, run: {module, _opts}}) when is_atom(module) do
      if reactor?(module), do: module
    end

    def run_by(_action), do: nil

    defimpl Clarity.Vertex do
      alias Clarity.Vertex.Util

      @impl Clarity.Vertex
      def id(%@for{reactor: reactor}), do: Util.id(@for, [reactor])

      @impl Clarity.Vertex
      def type_label(_vertex), do: inspect(Reactor)

      @impl Clarity.Vertex
      def name(%@for{reactor: reactor}), do: inspect(reactor)
    end

    defimpl Clarity.Vertex.GraphShapeProvider do
      @impl Clarity.Vertex.GraphShapeProvider
      def shape(_vertex), do: "cds"
    end

    defimpl Clarity.Vertex.ModuleProvider do
      @impl Clarity.Vertex.ModuleProvider
      def module(%@for{reactor: reactor}), do: reactor
    end

    defimpl Clarity.Vertex.SourceLocationProvider do
      @impl Clarity.Vertex.SourceLocationProvider
      def source_location(%@for{reactor: reactor}) do
        SourceLocation.from_module(reactor)
      end
    end

    defimpl Clarity.Vertex.TooltipProvider do
      @impl Clarity.Vertex.TooltipProvider
      def tooltip(%@for{reactor: reactor}) do
        [
          "`",
          inspect(reactor),
          "`\n\n",
          case Code.fetch_docs(reactor) do
            {:docs_v1, _annotation, _beam_language, "text/markdown", %{"en" => moduledoc},
             _metadata, _docs} ->
              moduledoc

            _ ->
              []
          end
        ]
      end
    end

    defimpl Clarity.Vertex.HintProvider do
      @impl HintProvider
      def icon(_vertex), do: :reactor

      @impl HintProvider
      def badges(_vertex), do: []

      @impl HintProvider
      def facts(%@for{reactor: reactor}) do
        reactor = Reactor.Info.to_struct!(reactor)

        [
          {"Inputs", Enum.map(reactor.inputs, &input_name/1)},
          {"Steps", Integer.to_string(length(reactor.steps))},
          {"Returns", inspect(reactor.return)}
        ]
      end

      @spec input_name(Reactor.Input.t() | atom()) :: String.t()
      defp input_name(%Reactor.Input{name: name}), do: Atom.to_string(name)
      defp input_name(name) when is_atom(name), do: Atom.to_string(name)
    end
  end
end
