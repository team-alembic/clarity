defmodule Clarity.Report do
  @moduledoc """
  Behaviour for reports — lens-scoped roll-ups of the graph rendered as a single
  interactive view, an alternative to navigating the graph vertex by vertex.

  A report declares its `name/0`, an optional `description/0`, and which lens it
  `applies?/1` to. The module is also a LiveComponent (`use Clarity.Web,
  :live_component`) — `Clarity.ReportLive` embeds the selected report and passes
  it `graph` and `lens` assigns, so a report can query
  `Clarity.Graph.vertices(graph, lens.filter)` and reuse the per-vertex analysis.

  Reports are registered per-application under `:clarity_reports` and discovered
  via `Clarity.Config.list_reports/0`:

      config :my_app, :clarity_reports, [MyApp.Report.Compliance]

  ## Example

      defmodule MyApp.Report.Compliance do
        @behaviour Clarity.Report
        use Clarity.Web, :live_component

        @impl Clarity.Report
        def name, do: "Compliance"

        @impl Clarity.Report
        def applies?(%Clarity.Perspective.Lens{id: "security"}), do: true
        def applies?(_lens), do: false

        @impl Phoenix.LiveComponent
        def update(assigns, socket), do: {:ok, assign(socket, assigns)}

        @impl Phoenix.LiveComponent
        def render(assigns), do: ~H"..."
      end
  """

  alias Clarity.Perspective.Lens

  @callback name() :: String.t()
  @callback description() :: String.t() | nil
  @callback applies?(lens :: Lens.t()) :: boolean()

  @optional_callbacks [description: 0]

  @doc """
  Reports applicable to `lens`, sorted by name.
  """
  @spec applicable(Lens.t()) :: [module()]
  def applicable(lens) do
    Clarity.Config.list_reports()
    |> Enum.filter(&applies?(&1, lens))
    |> Enum.sort_by(& &1.name())
  end

  @doc """
  Finds an applicable report by its URL id, or `:error`.
  """
  @spec fetch(Lens.t(), String.t()) :: {:ok, module()} | :error
  def fetch(lens, id) do
    case Enum.find(applicable(lens), &(report_id(&1) == id)) do
      nil -> :error
      report -> {:ok, report}
    end
  end

  @doc """
  The stable URL id for a report module.

  ## Examples

      iex> Clarity.Report.report_id(Clarity.Report.SupplyChain)
      "supply-chain"
  """
  @spec report_id(module()) :: String.t()
  def report_id(report) do
    report
    |> Macro.underscore()
    |> String.replace(~r/[_\/]+/, "-")
    |> String.replace_prefix("clarity-report-", "")
  end

  @doc """
  The report's description, or `nil` if it doesn't define one.
  """
  @spec description(module()) :: String.t() | nil
  def description(report) do
    if function_exported?(report, :description, 0), do: report.description()
  end

  @spec applies?(module(), Lens.t()) :: boolean()
  defp applies?(report, lens) do
    Code.ensure_loaded?(report) and function_exported?(report, :applies?, 1) and
      report.applies?(lens)
  end
end
