defmodule Clarity.Vertex.Advisory do
  @moduledoc """
  Vertex implementation for a security advisory affecting a dependency.
  """

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
end
