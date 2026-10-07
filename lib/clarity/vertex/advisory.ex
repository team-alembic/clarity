defmodule Clarity.Vertex.Advisory do
  @moduledoc """
  Vertex implementation for a security advisory affecting a dependency.
  """

  alias Clarity.Vertex.HintProvider

  @type t() :: %__MODULE__{advisory: Clarity.Advisory.t()}
  @enforce_keys [:advisory]
  defstruct [:advisory]

  defimpl Clarity.Vertex do
    alias Clarity.Vertex.Util

    @impl Clarity.Vertex
    def id(%@for{advisory: advisory}), do: Util.id(@for, [advisory.id])

    @impl Clarity.Vertex
    def type_label(_vertex), do: "Advisory"

    @impl Clarity.Vertex
    def name(%@for{advisory: advisory}), do: advisory.id
  end

  defimpl Clarity.Vertex.GraphShapeProvider do
    @impl Clarity.Vertex.GraphShapeProvider
    def shape(_vertex), do: "octagon"
  end

  defimpl Clarity.Vertex.TooltipProvider do
    @impl Clarity.Vertex.TooltipProvider
    def tooltip(%@for{advisory: advisory}) do
      [
        "**Advisory:** `",
        advisory.id,
        "`\n\n",
        case advisory.severity do
          nil -> []
          severity -> ["**Severity:** ", severity, "\n\n"]
        end,
        advisory.summary || ""
      ]
    end
  end

  defimpl Clarity.Vertex.HintProvider do
    @impl HintProvider
    def icon(_vertex), do: :advisory

    @impl HintProvider
    def badges(%@for{advisory: advisory}), do: List.wrap(advisory.severity)

    @impl HintProvider
    def facts(%@for{advisory: advisory}) do
      [
        {"Package", advisory.package}
        | case advisory.aliases do
            empty when empty in [nil, []] -> []
            aliases -> [{"Aliases", aliases}]
          end
      ]
    end
  end
end
