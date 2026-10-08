defmodule Clarity.ReportLive do
  @moduledoc false

  # Serves two sections of the activity bar, which share a layout: Reports,
  # each report to read, and Actions, the things to do each report finds
  # (`c:Clarity.Report.actions/2`). Both list their reports in a sidebar tree
  # grouped by category; under Actions each row counts its to-dos.

  use Clarity.Web, :live_view

  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker
  alias Clarity.Report
  alias Clarity.Report.Action
  alias Clarity.Report.Actions
  alias Clarity.Report.Components
  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveView.Socket

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Clarity.subscribe(socket.assigns.clarity_pid, [:work_started, :work_completed])
    end

    {:ok,
     socket
     |> assign(
       show_navigation: false,
       lenses: Lensmaker.get_all_lenses(),
       lens: default_lens(),
       selected: nil,
       report_actions: AsyncResult.loading()
     )
     |> fetch_clarity()}
  end

  # The bare index, and an unknown report id, patch to the first report so the
  # URL always names the report shown.
  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    section =
      if socket.assigns.live_action in [:actions, :report_actions], do: :actions, else: :reports

    {reports, groups} =
      case section do
        :actions -> {Enum.filter(Report.all(), &Report.actions?/1), Report.grouped_with_actions()}
        :reports -> {Report.all(), Report.grouped()}
      end

    {:noreply,
     socket
     |> assign(section: section, reports: reports, report_groups: groups)
     |> select_report(params["report_id"])}
  end

  # The header's menu button, which shows the sidebar on narrow screens.
  @impl Phoenix.LiveView
  def handle_event("toggle_navigation", _params, socket) do
    {:noreply, assign(socket, show_navigation: not socket.assigns.show_navigation)}
  end

  @impl Phoenix.LiveView
  def handle_info({:clarity, event}, socket) when event in [:work_started, :work_completed] do
    {:noreply, socket |> fetch_clarity() |> assign_report_actions()}
  end

  def handle_info({:"ETS-TRANSFER", _ref, _pid, :graph_handover}, socket) do
    {:noreply, socket}
  end

  @spec select_report(Socket.t(), String.t() | nil) :: Socket.t()
  defp select_report(socket, report_id) do
    case {socket.assigns.reports, report_id && Report.fetch(report_id)} do
      {[], _report} ->
        assign(socket, selected: nil)

      {[first | _] = reports, {:ok, report}} ->
        if report in reports do
          socket |> assign(selected: report) |> assign_report_actions()
        else
          push_patch(socket, to: section_path(socket, first))
        end

      {[first | _], _missing} ->
        push_patch(socket, to: section_path(socket, first))
    end
  end

  # Under Actions, the selected report's things to do, worked out off the page
  # (they can take a while) and cached per change to the graph.
  @spec assign_report_actions(Socket.t()) :: Socket.t()
  defp assign_report_actions(%{assigns: %{section: :actions, selected: report}} = socket)
       when report != nil do
    if connected?(socket) do
      graph = socket.assigns.graph
      opts = [name_style: socket.assigns.name_style]

      assign_async(socket, :report_actions, fn ->
        {:ok,
         %{
           report_actions: %{
             actions: Actions.for_report(graph, report, opts),
             pending: Report.pending(report, graph)
           }
         }}
      end)
    else
      assign(socket, report_actions: AsyncResult.loading())
    end
  end

  defp assign_report_actions(socket), do: socket

  attr :report, :atom, required: true
  attr :selected, :atom, required: true
  attr :path, :string, required: true
  attr :tally, :map, default: nil

  # A report's row in the sidebar tree, styled like a row of the Explore tree.
  @spec report_link(map()) :: Phoenix.LiveView.Rendered.t()
  defp report_link(assigns) do
    ~H"""
    <.link
      patch={@path}
      aria-current={@report == @selected && "page"}
      title={Report.description(@report)}
      class={[
        "flex min-w-0 items-center gap-1 px-1 py-px rounded-xs hover:bg-base-light-200 dark:hover:bg-base-dark-700 hover:text-primary-light dark:hover:text-primary-dark transition-colors font-medium",
        @report == @selected &&
          "bg-primary-light dark:bg-primary-dark text-white dark:text-base-dark-900"
      ]}
    >
      <.icon_report class="tree-icon" aria-hidden="true" />
      <span class="truncate">{@report.name()}</span>
      <Components.count_badge tally={@tally} />
    </.link>
    """
  end

  # The report's tally, once counted.
  @spec tally_for(term(), module()) :: Action.tally() | nil
  defp tally_for(%AsyncResult{ok?: true, result: tallies}, report), do: tallies[report]
  defp tally_for(_tallies, _report), do: nil

  # A category's reports' tallies summed, once counted.
  @spec category_tally(term(), [module()]) :: Action.tally() | nil
  defp category_tally(%AsyncResult{ok?: true, result: tallies}, reports),
    do: reports |> Enum.map(&tallies[&1]) |> Enum.reject(&is_nil/1) |> Action.sum()

  defp category_tally(_tallies, _reports), do: nil

  @spec category_id(String.t()) :: String.t()
  defp category_id(category),
    do: category |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")

  @spec fetch_clarity(Socket.t()) :: Socket.t()
  defp fetch_clarity(socket) do
    clarity = Clarity.get(socket.assigns.clarity_pid, :partial)

    assign(socket,
      graph: clarity.graph,
      version: Graph.get_update_count(clarity.graph),
      working?: clarity.status == :working
    )
  end

  # Reports aren't seen through a lens, but their links into the graph need
  # one: the default lens, where Clarity starts.
  @spec default_lens() :: Lens.t()
  defp default_lens do
    {:ok, lens} = Lensmaker.get_lens_by_id(Clarity.Config.fetch_default_perspective_lens!())
    lens
  end

  @spec section_path(Socket.t(), module()) :: String.t()
  defp section_path(socket, report),
    do: section_path(socket.assigns.prefix, socket.assigns.section, report)

  @spec section_path(String.t(), atom(), module()) :: String.t()
  defp section_path(prefix, section, report),
    do: Path.join([prefix, Atom.to_string(section), Report.report_id(report)])
end
