defmodule Clarity.Report.Charts do
  @moduledoc """
  Small presentational chart components for reports — KPI stat cards and a pie
  chart — giving a report an at-a-glance executive summary above its prose.

  The pie is a server-rendered SVG from [`contex`](https://hex.pm/packages/contex)
  (no JavaScript). Segment/card colour is chosen by `tone`: `:ok`, `:info`,
  `:warning`, `:error`, or `:neutral`.
  """

  use Clarity.Web, :html

  alias Contex.Dataset
  alias Contex.PieChart
  alias Contex.Plot
  alias Phoenix.LiveView.Rendered

  @type segment() :: %{label: String.t(), value: number(), tone: atom()}

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :tone, :atom, default: :neutral

  @doc "A KPI stat card: a big number with a label, tinted by tone."
  @spec stat(map()) :: Rendered.t()
  def stat(assigns) do
    ~H"""
    <div class={["rounded-lg p-4 ring-1 ring-inset", card_classes(@tone)]}>
      <div class="text-3xl font-bold tabular-nums leading-none">{@value}</div>
      <div class="text-sm mt-1 opacity-80">{@label}</div>
    </div>
    """
  end

  attr :segments, :list, required: true, doc: "list of %{label, value, tone}"
  attr :title, :string, default: nil

  @doc "A pie chart of `segments`, server-rendered as SVG via contex."
  @spec pie(map()) :: Rendered.t()
  def pie(assigns) do
    assigns = assign(assigns, :svg, pie_svg(Enum.reject(assigns.segments, &(&1.value == 0))))

    ~H"""
    <figure :if={@svg} class="contex-chart text-base-light-900 dark:text-base-dark-100">
      <figcaption :if={@title} class="text-sm font-medium mb-1">{@title}</figcaption>
      {@svg}
    </figure>
    """
  end

  @spec pie_svg([segment()]) :: {:safe, iodata()} | nil
  defp pie_svg([]), do: nil

  defp pie_svg(segments) do
    segments
    |> Enum.map(&[&1.label, &1.value])
    |> Dataset.new(["label", "value"])
    |> Plot.new(PieChart, 360, 220,
      mapping: %{category_col: "label", value_col: "value"},
      colour_palette: Enum.map(segments, &palette(&1.tone)),
      data_labels: true,
      legend_setting: :legend_right
    )
    |> Plot.to_svg()
  end

  @spec card_classes(atom()) :: String.t()
  defp card_classes(:ok),
    do: "bg-green-50 dark:bg-green-500/10 text-green-800 dark:text-green-200 ring-green-600/20"

  defp card_classes(:info),
    do: "bg-blue-50 dark:bg-blue-500/10 text-blue-800 dark:text-blue-200 ring-blue-600/20"

  defp card_classes(:warning),
    do:
      "bg-yellow-50 dark:bg-yellow-500/10 text-yellow-800 dark:text-yellow-200 ring-yellow-600/20"

  defp card_classes(:error),
    do: "bg-red-50 dark:bg-red-500/10 text-red-800 dark:text-red-200 ring-red-600/20"

  defp card_classes(_neutral),
    do:
      "bg-base-light-100 dark:bg-base-dark-800 text-base-light-900 dark:text-base-dark-100 ring-base-light-300 dark:ring-base-dark-600"

  # contex colour palettes are hex strings without the leading `#`.
  @spec palette(atom()) :: String.t()
  defp palette(:ok), do: "10b981"
  defp palette(:info), do: "3b82f6"
  defp palette(:warning), do: "f59e0b"
  defp palette(:error), do: "ef4444"
  defp palette(_neutral), do: "94a3b8"
end
