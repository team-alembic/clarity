defprotocol Clarity.Vertex.HintProvider do
  @moduledoc """
  Protocol for the structured parts of a vertex's hover hint.

  `Clarity.Tooltip` shows these alongside the vertex name and the one-line
  summary from `Clarity.Vertex.TooltipProvider`:

    * an **icon** on the type pill, telling vertex types apart at a glance
    * **badges** for notable flags, such as `primary` or `sensitive`
    * **facts**, a few label/value rows read straight from the vertex

  Values should be short plain text; `Clarity.Tooltip` truncates long ones.
  Like `Clarity.Vertex.TooltipProvider`, this is called for every vertex
  rendered in the tree and graph, so it should be cheap.
  """

  @fallback_to_any true

  @typedoc "An icon from the set Clarity ships, see `Clarity.Tooltip.icons/0`."
  @type icon() ::
          :action
          | :advisory
          | :aggregate
          | :application
          | :attribute
          | :calculation
          | :data_layer
          | :domain
          | :dsl
          | :endpoint
          | :entity
          | :extension
          | :generic
          | :module
          | :policy
          | :relationship
          | :resource
          | :router
          | :section
          | :type

  @typedoc "A label and its value, or a list of values shown as chips."
  @type fact() :: {label :: String.t(), value :: String.t() | [String.t()]}

  @doc "Returns the icon shown on the vertex's type pill."
  @spec icon(t()) :: icon()
  def icon(vertex)

  @doc "Returns short flags worth calling out, such as `\"primary\"`."
  @spec badges(t()) :: [String.t()]
  def badges(vertex)

  @doc "Returns label/value facts about the vertex, most useful first."
  @spec facts(t()) :: [fact()]
  def facts(vertex)
end

defimpl Clarity.Vertex.HintProvider, for: Any do
  @moduledoc false

  @impl Clarity.Vertex.HintProvider
  def icon(_vertex), do: :generic

  @impl Clarity.Vertex.HintProvider
  def badges(_vertex), do: []

  @impl Clarity.Vertex.HintProvider
  def facts(_vertex), do: []
end
