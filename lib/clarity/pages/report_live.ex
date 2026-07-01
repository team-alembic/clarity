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
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    clarity = Clarity.get(socket.assigns.clarity_pid, :partial)

    case Lensmaker.get_lens_by_id(params["lens"]) do
      {:ok, lens} ->
        handle_lens(socket, lens, Report.applicable(lens), clarity.graph, params)

      {:error, :lens_not_found} ->
        {:noreply, assign(socket, lens: nil, reports: [], selected: nil, graph: clarity.graph)}
    end
  end

  # A lens with reports at the bare `/report` index redirects to its first report
  # so the URL always names the shown report.
  @spec handle_lens(Socket.t(), Lens.t(), [module()], Graph.t(), map()) ::
          {:noreply, Socket.t()}
  defp handle_lens(socket, lens, [first | _] = reports, graph, params) do
    case params["report_id"] do
      nil ->
        {:noreply, push_patch(socket, to: report_path(socket, lens, first))}

      report_id ->
        selected =
          case Report.fetch(lens, report_id) do
            {:ok, report} -> report
            :error -> first
          end

        {:noreply, assign(socket, lens: lens, reports: reports, selected: selected, graph: graph)}
    end
  end

  defp handle_lens(socket, lens, [], graph, _params) do
    {:noreply, assign(socket, lens: lens, reports: [], selected: nil, graph: graph)}
  end

  @spec report_path(Socket.t(), Lens.t(), module()) :: String.t()
  defp report_path(socket, lens, report) do
    Path.join([socket.assigns.prefix, lens.id, "report", Report.report_id(report)])
  end
end
