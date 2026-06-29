defmodule Clarity.Content.Dependency do
  @moduledoc """
  Security-lens content showing a dependency's version status: how it compares to
  the latest published version, and whether the installed version is retired.

  Reads `Clarity.Dependency.Registry`. This is a dependency-hygiene signal
  distinct from advisories, shown alongside them on the Application vertex.
  """

  @behaviour Clarity.Content

  alias Clarity.Dependency
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
        status_table(installed, summary)

      true ->
        ["## Version Status\n\n", "`#{app}` is not published on Hex.\n\n"]
    end
  end

  @spec status_table(String.t(), Dependency.summary()) :: iodata()
  defp status_table(installed, %{latest: latest, retired: retired}) do
    [
      "## Version Status\n\n",
      "| Property | Value |\n| --- | --- |\n",
      "| **Installed** | `",
      installed,
      "` |\n",
      "| **Latest** | ",
      if(latest, do: ["`", latest, "`"], else: "—"),
      " |\n",
      "| **Status** | ",
      status(installed, latest, retired),
      " |\n\n"
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
end
