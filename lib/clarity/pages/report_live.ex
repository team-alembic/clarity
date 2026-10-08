defmodule Clarity.ReportLive do
  @moduledoc false

  use Clarity.Web, :live_view

  alias Clarity.Graph
  alias Clarity.Perspective.Lens
  alias Clarity.Perspective.Lensmaker
  alias Clarity.Report
  alias Phoenix.LiveView.Socket

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Clarity.subscribe(socket.assigns.clarity_pid, [:work_started, :work_completed])
    end

    {:ok,
     socket
     |> assign(reports: Report.all(), report_groups: Report.grouped(), show_navigation: false)
     |> fetch_clarity()}
  end

  # Every report is listed whatever the lens; the lens stays in the URL so the
  # header's Explore item returns to the same lens. An unknown lens moves to the
  # default one, and the bare index or an unknown report id patches to the first
  # report, so the URL always names the lens and report shown.
  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    case Lensmaker.get_lens_by_id(params["lens"]) do
      {:ok, lens} ->
        {:noreply, socket |> assign(lens: lens) |> select_report(params["report_id"])}

      {:error, :lens_not_found} ->
        default = Clarity.Config.fetch_default_perspective_lens!()

        {:noreply,
         push_navigate(socket, to: Path.join([socket.assigns.prefix, default, "reports"]))}
    end
  end

  # The header's menu button, which shows the sidebar on narrow screens.
  @impl Phoenix.LiveView
  def handle_event("toggle_navigation", _params, socket) do
    {:noreply, assign(socket, show_navigation: not socket.assigns.show_navigation)}
  end

  @impl Phoenix.LiveView
  def handle_info({:clarity, event}, socket) when event in [:work_started, :work_completed] do
    {:noreply, fetch_clarity(socket)}
  end

  def handle_info({:"ETS-TRANSFER", _ref, _pid, :graph_handover}, socket) do
    {:noreply, socket}
  end

  @spec select_report(Socket.t(), String.t() | nil) :: Socket.t()
  defp select_report(socket, report_id) do
    case {socket.assigns.reports, report_id && Report.fetch(report_id)} do
      {[], _report} ->
        assign(socket, selected: nil)

      {_reports, {:ok, report}} ->
        assign(socket, selected: report)

      {[first | _], _missing} ->
        push_patch(socket, to: report_path(socket.assigns.prefix, socket.assigns.lens, first))
    end
  end

  attr :report, :atom, required: true
  attr :selected, :atom, required: true
  attr :prefix, :string, required: true
  attr :lens, Lens, required: true

  # A report's row in the sidebar tree, styled like a row of the Explore tree.
  @spec report_link(map()) :: Phoenix.LiveView.Rendered.t()
  defp report_link(assigns) do
    ~H"""
    <.link
      patch={report_path(@prefix, @lens, @report)}
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
    </.link>
    """
  end

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

  # Where the lens switcher goes from here: the same report under another lens.
  @spec report_lens_path(String.t(), String.t(), module() | nil) :: String.t()
  defp report_lens_path(prefix, lens_id, nil), do: Path.join([prefix, lens_id, "reports"])

  defp report_lens_path(prefix, lens_id, report),
    do: Path.join([prefix, lens_id, "reports", Report.report_id(report)])

  @spec report_path(String.t(), Lens.t(), module()) :: String.t()
  defp report_path(prefix, lens, report) do
    Path.join([prefix, lens.id, "reports", Report.report_id(report)])
  end
end
