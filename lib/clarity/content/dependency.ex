defmodule Clarity.Content.Dependency do
  @moduledoc """
  Security-lens content showing a dependency's version status: how it compares to
  the latest published version, whether the installed version is retired, and —
  in the dev environment — an action to update it in place.

  Reads `Clarity.Dependency.Registry`. The update action (dev-only) runs
  `Clarity.Dependency.Updater`, optionally widening the `mix.exs` requirement via
  the `clarity.update_dep` igniter task first.
  """

  @behaviour Clarity.Content

  use Clarity.Web, :live_component

  alias Clarity.Dependency
  alias Clarity.Dependency.Constraints
  alias Clarity.Dependency.Registry
  alias Clarity.Dependency.Updater
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex

  @impl Clarity.Content
  def name, do: "Version Status"

  @impl Clarity.Content
  def description, do: "Latest-version and retirement status for this dependency"

  @impl Clarity.Content
  def sort_priority, do: -90

  @impl Clarity.Content
  def applies?(%Vertex.Application{}, %Lens{id: "security"}), do: true
  def applies?(_vertex, _lens), do: false

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    %Vertex.Application{app: app, version: version} = assigns.vertex
    installed = to_string(version)

    {:ok,
     socket
     |> assign(app: app, installed: installed, view: build_view(app, installed))
     |> assign_new(:updating?, fn -> false end)
     |> assign_new(:result, fn -> nil end)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("update", _params, socket) do
    {:ok, data} = socket.assigns.view
    app = socket.assigns.app
    requirement = widen_requirement(data.status)

    {:noreply,
     socket
     |> assign(updating?: true, result: nil)
     |> start_async(:update, fn -> Updater.update(app, requirement) end)}
  end

  @impl Phoenix.LiveComponent
  def handle_async(:update, {:ok, :ok}, socket) do
    message = "Updated and reloaded #{socket.assigns.app}. Re-introspect to refresh the graph."
    {:noreply, assign(socket, updating?: false, result: {:ok, message})}
  end

  def handle_async(:update, {:ok, {:error, reason}}, socket) do
    {:noreply, assign(socket, updating?: false, result: {:error, inspect(reason)})}
  end

  def handle_async(:update, {:exit, reason}, socket) do
    {:noreply, assign(socket, updating?: false, result: {:error, inspect(reason)})}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <section class="content w-full flex justify-center">
      <div class="p-4 max-w-[100ch] w-full">
        <h2 class="text-xl font-semibold mb-4">Version Status</h2>

        <%= case @view do %>
          <% :pending -> %>
            <p class="italic opacity-70">Hex registry not yet downloaded.</p>
          <% :not_published -> %>
            <p><code>{@app}</code> is not published on Hex.</p>
          <% {:ok, data} -> %>
            <table class="w-full mb-4">
              <tbody>
                <tr>
                  <td class="font-medium pr-4">Installed</td>
                  <td><code>{@installed}</code></td>
                </tr>
                <tr>
                  <td class="font-medium pr-4">Latest</td>
                  <td>{if data.latest, do: raw_code(data.latest), else: "—"}</td>
                </tr>
                <tr :if={data.requirement}>
                  <td class="font-medium pr-4">Constraint</td>
                  <td>{raw_code(data.requirement)}</td>
                </tr>
                <tr>
                  <td class="font-medium pr-4">Status</td>
                  <td>{data.status_label}</td>
                </tr>
              </tbody>
            </table>

            <%= if show_button?(data.status) do %>
              <button
                type="button"
                phx-click="update"
                phx-target={@myself}
                disabled={@updating?}
                class="px-3 py-2 rounded-md bg-primary-light dark:bg-primary-dark text-white hover:bg-primary-light/90 dark:hover:bg-primary-dark/90 disabled:opacity-50 transition-colors cursor-pointer"
              >
                {if @updating?, do: "Updating…", else: button_label(data.status)}
              </button>
            <% end %>

            <p :if={blocked_without_igniter?(data.status)} class="mt-2 opacity-70">
              Widen the requirement in <code>mix.exs</code> to allow {data.latest}.
            </p>
        <% end %>

        <%= case @result do %>
          <% {:ok, message} -> %>
            <p class="mt-4 text-green-700 dark:text-green-400">{message}</p>
          <% {:error, message} -> %>
            <p class="mt-4 font-semibold text-base-light-900 dark:text-base-dark-100">
              Update failed: {message}
            </p>
          <% nil -> %>
        <% end %>
      </div>
    </section>
    """
  end

  @spec build_view(atom(), String.t()) ::
          :pending | :not_published | {:ok, map()}
  defp build_view(app, installed) do
    cond do
      not Registry.ready?() ->
        :pending

      summary = Registry.summary(app) ->
        requirement = Constraints.requirement(app)

        {:ok,
         %{
           latest: summary.latest,
           requirement: requirement,
           status: Dependency.update_status(installed, summary.latest, requirement),
           status_label: status_label(installed, summary)
         }}

      true ->
        :not_published
    end
  end

  @spec status_label(String.t(), Dependency.summary()) :: String.t()
  defp status_label(installed, %{latest: latest, retired: retired}) do
    cond do
      installed in retired -> "⚠ retired"
      Dependency.outdated?(installed, latest) -> "⚠ outdated"
      true -> "up to date"
    end
  end

  # The update action only exists in dev (deps compile in the consumer's env),
  # so the button-gating helpers are compiled away to `false` everywhere else.
  if Mix.env() == :dev do
    @spec show_button?(Dependency.update_status()) :: boolean()
    defp show_button?({:updatable, _latest}), do: true
    defp show_button?({:unconstrained, _latest}), do: true
    defp show_button?({:constraint_blocks, _latest, _req}), do: can_widen?()
    defp show_button?(:up_to_date), do: false

    @spec blocked_without_igniter?(Dependency.update_status()) :: boolean()
    defp blocked_without_igniter?({:constraint_blocks, _latest, _req}), do: not can_widen?()
    defp blocked_without_igniter?(_status), do: false

    @spec can_widen?() :: boolean()
    defp can_widen?, do: Code.ensure_loaded?(Mix.Tasks.Clarity.UpdateDep)
  else
    @spec show_button?(Dependency.update_status()) :: boolean()
    defp show_button?(_status), do: false

    @spec blocked_without_igniter?(Dependency.update_status()) :: boolean()
    defp blocked_without_igniter?(_status), do: false
  end

  @spec button_label(Dependency.update_status()) :: String.t()
  defp button_label({:constraint_blocks, latest, _req}),
    do: "Widen mix.exs and update to #{latest}"

  defp button_label({_status, latest}), do: "Update to #{latest}"

  @spec widen_requirement(Dependency.update_status()) :: String.t() | nil
  defp widen_requirement({:constraint_blocks, latest, _req}) do
    case Version.parse(latest) do
      {:ok, %Version{major: major, minor: minor}} -> "~> #{major}.#{minor}"
      :error -> nil
    end
  end

  defp widen_requirement(_status), do: nil

  @spec raw_code(String.t()) :: Phoenix.LiveView.Rendered.t()
  defp raw_code(text) do
    assigns = %{text: text}
    ~H"<code>{@text}</code>"
  end
end
