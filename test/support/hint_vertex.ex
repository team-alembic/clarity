defmodule Clarity.Test.HintVertex do
  # A vertex whose hint parts are whatever the test gives it.
  @moduledoc false

  alias Clarity.Vertex.HintProvider

  defstruct icon: :generic, badges: [], facts: []

  defimpl Clarity.Vertex do
    @impl Clarity.Vertex
    def id(_vertex), do: "hint-vertex"

    @impl Clarity.Vertex
    def type_label(_vertex), do: "Hint Vertex"

    @impl Clarity.Vertex
    def name(_vertex), do: "hint vertex"
  end

  defimpl Clarity.Vertex.HintProvider do
    @impl HintProvider
    def icon(%@for{icon: icon}), do: icon

    @impl HintProvider
    def badges(%@for{badges: badges}), do: badges

    @impl HintProvider
    def facts(%@for{facts: facts}), do: facts
  end
end
