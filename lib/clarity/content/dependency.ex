defmodule Clarity.Content.Dependency do
  @moduledoc """
  Security-lens content showing a dependency's version status: how it compares to
  the latest published version, and whether the installed version is retired.

  Reads `Clarity.Dependency.Registry`. This is a dependency-hygiene signal
  distinct from advisories, shown alongside them on the Application vertex.
  """

  @behaviour Clarity.Content

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

  @impl Clarity.Content
  def render_static(%Vertex.Application{app: app, version: version}, _lens) do
    {:markdown, fn _props -> markdown(app, to_string(version)) end}
  end

  @spec markdown(atom(), String.t()) :: iodata()
  defp markdown(app, installed) do
    cond do
      not Registry.ready?() ->
        ["## Version Status\n\n", "_Hex registry not yet downloaded._\n\n"]

      summary = Registry.summary(app) ->
        status_table(app, installed, summary)

      true ->
        ["## Version Status\n\n", "`#{app}` is not published on Hex.\n\n"]
    end
  end

  @spec status_table(atom(), String.t(), Dependency.summary()) :: iodata()
  defp status_table(app, installed, %{latest: latest, retired: retired}) do
    requirement = Constraints.requirement(app)

    [
      "## Version Status\n\n",
      "| Property | Value |\n| --- | --- |\n",
      "| **Installed** | `",
      installed,
      "` |\n",
      "| **Latest** | ",
      if(latest, do: ["`", latest, "`"], else: "—"),
      " |\n",
      case requirement do
        nil -> []
        req -> ["| **Constraint** | `", req, "` |\n"]
      end,
      "| **Status** | ",
      status(installed, latest, retired),
      " |\n\n",
      update_note(app, installed, latest, retired, requirement)
    ]
  end

  @spec status(String.t(), String.t() | nil, [String.t()]) :: String.t()
  defp status(installed, latest, retired) do
    cond do
      installed in retired -> "⚠ retired"
      Dependency.outdated?(installed, latest) -> "⚠ outdated"
      true -> "up to date"
    end
  end

  @spec update_note(atom(), String.t(), String.t() | nil, [String.t()], String.t() | nil) ::
          iodata()
  defp update_note(app, installed, latest, retired, requirement) do
    case Dependency.update_status(installed, latest, requirement) do
      :up_to_date ->
        if installed in retired,
          do: "> ⚠ This installed version is retired — move to a supported version.\n\n",
          else: []

      {:updatable, version} ->
        [
          "> ⬆ `mix deps.update ",
          to_string(app),
          "` will update to ",
          version,
          " (within `",
          requirement,
          "`).\n\n"
        ]

      {:constraint_blocks, version, req} ->
        [
          "> ⚠ Latest ",
          version,
          " is outside your constraint `",
          req,
          "` — widen the requirement in `mix.exs` to update.\n\n"
        ]

      {:unconstrained, version} ->
        [
          "> ",
          version,
          " is available. This is a transitive dependency, so it ",
          "updates via its dependents (or add it directly with `override: true`).\n\n"
        ]
    end
  end
end
