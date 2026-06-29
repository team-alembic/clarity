defmodule Clarity.Content.Advisory do
  @moduledoc """
  Security-lens content for dependency advisories.

  On an `Application` vertex it lists the advisories affecting the installed
  version; on an `Advisory` vertex it shows the advisory detail. Both read from
  `Clarity.Advisory.Source`.
  """

  @behaviour Clarity.Content

  alias Clarity.Advisory.Source
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex
  alias Clarity.Vertex.Util

  @impl Clarity.Content
  def name, do: "Advisories"

  @impl Clarity.Content
  def description, do: "Known security advisories affecting this dependency"

  @impl Clarity.Content
  def sort_priority, do: -100

  @impl Clarity.Content
  def applies?(%Vertex.Application{}, %Lens{id: "security"}), do: true
  def applies?(%Vertex.Advisory{}, _lens), do: true
  def applies?(_vertex, _lens), do: false

  @impl Clarity.Content
  def render_static(%Vertex.Application{app: app, version: version}, _lens) do
    {:markdown, fn _props -> application_markdown(app, version) end}
  end

  def render_static(%Vertex.Advisory{advisory: advisory}, _lens) do
    {:markdown, fn _props -> advisory_markdown(advisory) end}
  end

  @spec application_markdown(atom(), charlist() | String.t()) :: iodata()
  defp application_markdown(app, version) do
    advisories = Source.advisories_for(app, version)

    [
      "## Security Advisories\n\n",
      freshness_note(),
      case advisories do
        [] ->
          "No known advisories for `#{app}` #{version}.\n\n"

        _present ->
          [
            "| Advisory | Severity | Summary |\n| --- | --- | --- |\n",
            Enum.map(advisories, &advisory_row/1),
            "\n"
          ]
      end
    ]
  end

  @spec advisory_row(Clarity.Advisory.t()) :: iodata()
  defp advisory_row(advisory) do
    [
      "| [",
      advisory.id,
      "](vertex://",
      Util.id(Vertex.Advisory, [advisory.id]),
      ") | ",
      advisory.severity || "—",
      " | ",
      advisory.summary || "",
      " |\n"
    ]
  end

  @spec advisory_markdown(Clarity.Advisory.t()) :: iodata()
  defp advisory_markdown(advisory) do
    [
      "# ",
      advisory.id,
      "\n\n",
      "| Property | Value |\n| --- | --- |\n",
      "| **Package** | `",
      advisory.package,
      "` |\n",
      "| **Severity** | ",
      advisory.severity || "—",
      " |\n",
      case advisory.aliases do
        [] -> []
        aliases -> ["| **Aliases** | ", Enum.map_join(aliases, ", ", &"`#{&1}`"), " |\n"]
      end,
      "\n",
      case advisory.summary do
        nil -> []
        summary -> [summary, "\n\n"]
      end,
      references_section(advisory.references)
    ]
  end

  @spec references_section([String.t()]) :: iodata()
  defp references_section([]), do: []

  defp references_section(references) do
    [
      "## References\n\n",
      Enum.map(references, &["- <", &1, ">\n"]),
      "\n"
    ]
  end

  @spec freshness_note() :: iodata()
  defp freshness_note do
    case Source.last_refreshed_at() do
      nil -> "_Advisory database not yet downloaded._\n\n"
      at -> ["_Advisory data as of #{DateTime.to_iso8601(at)}._\n\n"]
    end
  end
end
