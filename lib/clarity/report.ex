defmodule Clarity.Report do
  @moduledoc """
  Behaviour for reports: written documents that sum up part of the graph in one
  place, an alternative to navigating it vertex by vertex.

  Reports have their own icon in the activity bar, below the lenses, so no
  report is hidden behind a lens choice. Clarity renders them at
  `prefix/reports`: the sidebar lists every registered report as a tree,
  grouped by category, and the selected one fills the main pane under its
  name. A report declares its `name/0`, and optionally a `description/0` and
  the `category/0` it is grouped under.

  The module is also a LiveComponent (`use Clarity.Web, :live_component`).
  Clarity embeds the selected report with these assigns:

    * `graph` - the whole `Clarity.Graph`, not filtered by any lens; query it with
      `Clarity.Graph.vertices/2`, e.g.
      `Clarity.Graph.vertices(graph, {:==, :vertex_type, Clarity.Vertex.Application})`
    * `lens` - the default lens, for `Clarity.Components.MarkdownComponent`'s links
    * `prefix` - the URL prefix Clarity is mounted at
    * `version` - the graph's update count; it changes whenever introspection
      changes the graph, so `update/2` runs again and the report stays current
    * `link_lowercase` - whether the viewer has text link lowercase names too;
      pass it on to `Clarity.Components.MarkdownComponent`

  Reports are prose: they explain what's going on and why it matters, typically
  as generated markdown rendered with `Clarity.Components.MarkdownComponent`.

  Reports are registered per-application under `:clarity_reports`:

      config :my_app, :clarity_reports, [MyApp.Report.Compliance]

  ## Example

      defmodule MyApp.Report.Compliance do
        @behaviour Clarity.Report
        use Clarity.Web, :live_component

        @impl Clarity.Report
        def name, do: "Compliance"

        @impl Phoenix.LiveComponent
        def update(assigns, socket), do: {:ok, assign(socket, assigns)}

        @impl Phoenix.LiveComponent
        def render(assigns), do: ~H"..."
      end
  """

  @callback name() :: String.t()
  @callback description() :: String.t() | nil
  @callback category() :: String.t()

  @optional_callbacks [description: 0, category: 0]

  @doc """
  All registered reports, sorted by name.
  """
  @spec all() :: [module()]
  def all do
    Clarity.Config.list_reports()
    |> Enum.filter(&Code.ensure_loaded?/1)
    |> Enum.sort_by(& &1.name())
  end

  @doc """
  All registered reports grouped as the reports sidebar shows them: each
  category, sorted by name, with its reports; then the reports without one,
  under `nil`.
  """
  @spec grouped() :: [{String.t() | nil, [module()]}]
  def grouped do
    {uncategorised, categorised} = all() |> Enum.group_by(&category/1) |> Map.pop(nil, [])

    Enum.sort_by(categorised, &elem(&1, 0)) ++
      if(uncategorised == [], do: [], else: [{nil, uncategorised}])
  end

  @doc """
  Finds a registered report by its URL id, or `:error`.
  """
  @spec fetch(String.t()) :: {:ok, module()} | :error
  def fetch(id) do
    case Enum.find(all(), &(report_id(&1) == id)) do
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
    if Code.ensure_loaded?(report) and function_exported?(report, :description, 0),
      do: report.description()
  end

  @doc """
  The category the report is grouped under, or `nil` if it doesn't define one.
  """
  @spec category(module()) :: String.t() | nil
  def category(report) do
    if Code.ensure_loaded?(report) and function_exported?(report, :category, 0),
      do: report.category()
  end
end
