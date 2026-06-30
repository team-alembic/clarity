defmodule Clarity.Content.Dependency do
  @moduledoc """
  Security-lens content showing a dependency's version status: how it compares to
  the latest published version, whether the installed version is retired, and —
  in the dev environment — an action (the shared `Clarity.Content.DependencyUpdate`
  button) to update it to the latest.

  Reads `Clarity.Dependency.Registry`.
  """

  @behaviour Clarity.Content

  use Clarity.Web, :live_component

  alias Clarity.Content.DependencyUpdate
  alias Clarity.Dependency
  alias Clarity.Dependency.Constraints
  alias Clarity.Dependency.Registry
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
    {:ok, assign(socket, app: app, installed: installed, view: build_view(app, installed))}
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
              <.live_component
                module={DependencyUpdate}
                id="version-status-update"
                app={@app}
                requirement={Dependency.widen_requirement(data.status)}
                label={button_label(data.status)}
              />
            <% end %>

            <p :if={blocked_without_igniter?(data.status)} class="mt-2 opacity-70">
              Widen the requirement in <code>mix.exs</code> to allow {data.latest}.
            </p>
        <% end %>
      </div>
    </section>
    """
  end

  @spec build_view(atom(), String.t()) :: :pending | :not_published | {:ok, map()}
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

  @spec button_label(Dependency.update_status()) :: String.t()
  defp button_label({:constraint_blocks, latest, _req}),
    do: "Widen mix.exs and update to #{latest}"

  defp button_label({_status, latest}), do: "Update to #{latest}"

  @spec raw_code(String.t()) :: Phoenix.LiveView.Rendered.t()
  defp raw_code(text) do
    assigns = %{text: text}
    ~H"<code>{@text}</code>"
  end

  # Updates are a dev-time affordance, hidden where Mix isn't available (e.g. a
  # release). `Code.ensure_loaded?/1` is release-safe and not constant-folded;
  # the actual safety gate lives in Clarity.Dependency.Updater.
  @spec show_button?(Dependency.update_status()) :: boolean()
  defp show_button?(status) do
    mix_available?() and
      case status do
        {:updatable, _latest} -> true
        {:unconstrained, _latest} -> true
        {:constraint_blocks, _latest, _req} -> can_widen?()
        :up_to_date -> false
      end
  end

  @spec blocked_without_igniter?(Dependency.update_status()) :: boolean()
  defp blocked_without_igniter?({:constraint_blocks, _latest, _req}),
    do: mix_available?() and not can_widen?()

  defp blocked_without_igniter?(_status), do: false

  @spec can_widen?() :: boolean()
  defp can_widen?, do: Code.ensure_loaded?(Mix.Tasks.Clarity.UpdateDep)

  @spec mix_available?() :: boolean()
  defp mix_available?, do: Code.ensure_loaded?(Mix)
end
