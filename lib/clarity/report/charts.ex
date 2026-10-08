defmodule Clarity.Report.Charts do
  @moduledoc """
  Small presentational chart components for reports — KPI stat cards and a
  stacked bar — giving a report an at-a-glance summary beside its to-dos.

  Both are plain HTML styled with Tailwind (no JavaScript). Segment/card colour
  is chosen by `tone`: `:ok`, `:info`, `:warning`, `:error`, or `:neutral`.
  """

  use Clarity.Web, :html

  alias Phoenix.LiveView.Rendered

  @type segment() :: %{label: String.t(), value: number(), tone: atom()}

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :tone, :atom, default: :neutral

  @doc "A KPI stat card: a big number with a label, tinted by tone."
  @spec stat(map()) :: Rendered.t()
  def stat(assigns) do
    ~H"""
    <div class={["rounded-lg px-3 py-2.5 ring-1 ring-inset", card_classes(@tone)]}>
      <div class="text-2xl font-semibold tabular-nums leading-none">{@value}</div>
      <div class="mt-1 text-xs font-medium opacity-80">{@label}</div>
    </div>
    """
  end

  attr :segments, :list, required: true, doc: "list of %{label, value, tone}"
  attr :title, :string, default: nil

  @doc """
  A bar split into one segment per non-zero entry of `segments`, each as wide as
  its share of the total, with a legend. Renders nothing when the total is zero.
  """
  @spec stacked_bar(map()) :: Rendered.t()
  def stacked_bar(assigns) do
    segments = Enum.reject(assigns.segments, &(&1.value == 0))

    assigns =
      assign(assigns,
        segments: segments,
        total: segments |> Enum.map(& &1.value) |> Enum.sum()
      )

    ~H"""
    <figure :if={@total > 0} class="space-y-2 max-w-xl">
      <figcaption :if={@title} class="text-sm font-medium">{@title}</figcaption>
      <div
        role="img"
        aria-label={Enum.map_join(@segments, ", ", &"#{&1.label} #{&1.value}")}
        class="flex h-3 overflow-hidden rounded-full bg-base-light-200 dark:bg-base-dark-700"
      >
        <div
          :for={segment <- @segments}
          data-segment
          class={segment_classes(segment.tone)}
          style={"width: #{Float.round(segment.value / @total * 100, 2)}%"}
        />
      </div>
      <ul class="flex flex-wrap gap-x-4 gap-y-1 text-sm">
        <li :for={segment <- @segments} class="flex items-center gap-1.5">
          <span class={["size-2.5 rounded-sm", segment_classes(segment.tone)]} />
          {segment.label}
          <span class="tabular-nums text-base-light-600 dark:text-base-dark-400">
            {segment.value}
          </span>
        </li>
      </ul>
    </figure>
    """
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

  @spec segment_classes(atom()) :: String.t()
  defp segment_classes(:ok), do: "bg-green-500"
  defp segment_classes(:info), do: "bg-blue-500"
  defp segment_classes(:warning), do: "bg-yellow-500"
  defp segment_classes(:error), do: "bg-red-500"
  defp segment_classes(_neutral), do: "bg-base-light-400 dark:bg-base-dark-500"
end
