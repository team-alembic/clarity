defmodule Clarity.Content.Advisory do
  @moduledoc """
  Security-lens content for dependency advisories.

  On an `Application` vertex it lists the advisories affecting the installed
  version (with the version that fixes each), then what its dependencies,
  direct and transitive, need updating for: known advisories, retired
  versions and newer releases, together, so a project's page sums up what's
  beneath it. On an `Advisory` vertex it shows the advisory detail. When a released fix is installable, it offers the shared
  `Clarity.Content.DependencyUpdate` button to update the dependency.
  """

  @behaviour Clarity.Content

  use Clarity.Web, :live_component

  import Clarity.Components.MarkdownComponent

  alias Clarity.Advisory
  alias Clarity.Advisory.Source
  alias Clarity.Content.DependencyUpdate
  alias Clarity.Dependency
  alias Clarity.Dependency.Constraints
  alias Clarity.Dependency.Lock
  alias Clarity.Dependency.Registry
  alias Clarity.Graph
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
  def status_classes, do: [:security]

  @impl Clarity.Content
  def applies?(%Vertex.Application{}, %Lens{id: "security"}), do: true
  def applies?(%Vertex.Advisory{}, _lens), do: true
  def applies?(_vertex, _lens), do: false

  @impl Phoenix.LiveComponent
  def update(
        %{vertex: %Vertex.Application{app: app, version: version} = vertex} = assigns,
        socket
      ) do
    installed = to_string(version)
    dependencies = dependencies(assigns[:graph], vertex)

    {:ok,
     assign(socket,
       prefix: assigns.prefix,
       lens: assigns.lens,
       markdown: [
         application_markdown(app, installed),
         dependencies_markdown(dependencies)
       ],
       freshness: freshness(Source.last_refreshed_at()),
       update: build_update(app, installed)
     )}
  end

  def update(%{vertex: %Vertex.Advisory{advisory: advisory}} = assigns, socket) do
    installed = installed_version(advisory.package)

    {:ok,
     assign(socket,
       prefix: assigns.prefix,
       lens: assigns.lens,
       markdown: advisory_markdown(advisory, installed),
       freshness: nil,
       update: installed && build_update(app_atom(advisory.package), installed)
     )}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <section class="content w-full flex justify-center">
      <div class="p-4 max-w-[100ch] w-full">
        <.markdown content={@markdown} prefix={@prefix} lens={@lens} />

        <%= case @freshness do %>
          <% {:at, at} -> %>
            <p class="mt-2 text-sm italic opacity-70">
              Advisory data as of <time
                id="advisory-freshness"
                phx-hook="LocalTime"
                datetime={DateTime.to_iso8601(at)}
              >{format_refreshed(at)}</time>.
            </p>
          <% :never -> %>
            <p class="mt-2 text-sm italic opacity-70">Advisory database not yet downloaded.</p>
          <% nil -> %>
        <% end %>

        <%= if @update do %>
          <.live_component
            module={DependencyUpdate}
            id="advisory-update"
            app={@update.app}
            requirement={@update.requirement}
            label={@update.label}
          />
        <% end %>
      </div>
    </section>
    """
  end

  @spec application_markdown(atom(), String.t()) :: iodata()
  defp application_markdown(app, installed) do
    advisories = Source.advisories_for(app, installed)

    [
      "## Security Advisories\n\n",
      case advisories do
        [] ->
          if Lock.hex_package(app),
            do: "No known advisories for `#{app}` #{installed}.\n\n",
            else: "`#{app}` isn't installed from Hex, so it has no advisories of its own.\n\n"

        _present ->
          [
            "| Advisory | CVE | Severity | Fixed in | Summary |\n| --- | --- | --- | --- | --- |\n",
            Enum.map(advisories, &advisory_row(&1, installed)),
            "\n"
          ]
      end
    ]
  end

  # Every application `vertex` depends on, directly or through another.
  @spec dependencies(Graph.t() | nil, Vertex.Application.t()) :: [Vertex.Application.t()]
  defp dependencies(nil, _vertex), do: []

  defp dependencies(graph, vertex) do
    graph
    |> dependency_closure([vertex], MapSet.new([Vertex.id(vertex)]), [])
    |> Enum.sort_by(& &1.app)
  end

  @spec dependency_closure(Graph.t(), [Vertex.Application.t()], MapSet.t(String.t()), [
          Vertex.Application.t()
        ]) :: [Vertex.Application.t()]
  defp dependency_closure(_graph, [], _seen, found), do: found

  defp dependency_closure(graph, [vertex | rest], seen, found) do
    # The :dependency edges are the only ones from an application to another.
    new =
      graph
      |> Graph.out_neighbors(vertex)
      |> Enum.filter(&match?(%Vertex.Application{}, &1))
      |> Enum.uniq_by(&Vertex.id/1)
      |> Enum.reject(&MapSet.member?(seen, Vertex.id(&1)))

    seen = Enum.reduce(new, seen, &MapSet.put(&2, Vertex.id(&1)))
    dependency_closure(graph, new ++ rest, seen, new ++ found)
  end

  # Its dependencies' advisories and version status together: what needs
  # updating beneath it, worst first.
  @spec dependencies_markdown([Vertex.Application.t()]) :: iodata()
  defp dependencies_markdown([]), do: []

  defp dependencies_markdown(dependencies) do
    flagged =
      dependencies
      |> Enum.map(&standing/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(&{standing_rank(&1.standing), to_string(&1.dependency.app)})

    [
      "## Its Dependencies\n\n",
      summary_line(length(dependencies), Enum.frequencies_by(flagged, & &1.standing)),
      case flagged do
        [] ->
          []

        _present ->
          [
            "| Dependency | Installed | Latest | Standing | Advisories |\n| --- | --- | --- | --- | --- |\n",
            Enum.map(flagged, &dependency_row/1),
            "\n"
          ]
      end
    ]
  end

  @typep standing() :: %{
           dependency: Vertex.Application.t(),
           installed: String.t(),
           latest: String.t() | nil,
           advisories: [Advisory.t()],
           standing: :vulnerable | :retired | :outdated
         }

  # Where a dependency stands, or nil when it has nothing to update for (or
  # isn't a Hex package, which can't be checked).
  @spec standing(Vertex.Application.t()) :: standing() | nil
  defp standing(dependency) do
    installed = to_string(dependency.version)
    advisories = Source.advisories_for(dependency.app, installed)
    summary = Registry.summary(dependency.app)
    latest = summary && summary.latest

    standing =
      cond do
        advisories != [] -> :vulnerable
        summary && installed in summary.retired -> :retired
        Dependency.outdated?(installed, latest) -> :outdated
        true -> nil
      end

    if standing do
      %{
        dependency: dependency,
        installed: installed,
        latest: latest,
        advisories: advisories,
        standing: standing
      }
    end
  end

  @spec standing_rank(atom()) :: non_neg_integer()
  defp standing_rank(:vulnerable), do: 0
  defp standing_rank(:retired), do: 1
  defp standing_rank(:outdated), do: 2

  @spec summary_line(pos_integer(), %{atom() => pos_integer()}) :: String.t()
  defp summary_line(1, counts) when map_size(counts) == 0,
    do: "Its 1 dependency has no known advisory and is on its latest release.\n\n"

  defp summary_line(total, counts) when map_size(counts) == 0,
    do: "Its #{total} dependencies have no known advisories and are on their latest releases.\n\n"

  defp summary_line(total, counts) do
    parts =
      for {standing, phrase} <- [
            vulnerable: {"has a known advisory", "have known advisories"},
            retired: {"is on a retired version", "are on retired versions"},
            outdated: {"is behind its latest release", "are behind their latest release"}
          ],
          count = counts[standing] do
        {one, many} = phrase
        "#{count} #{if count == 1, do: one, else: many}"
      end

    "Of its #{count_noun(total, "dependency", "dependencies")}, #{join_and(parts)}.\n\n"
  end

  @spec join_and([String.t()]) :: String.t()
  defp join_and([one]), do: one
  defp join_and(parts), do: Enum.join(Enum.drop(parts, -1), ", ") <> " and " <> List.last(parts)

  @spec dependency_row(standing()) :: iodata()
  defp dependency_row(row) do
    [
      "| [",
      to_string(row.dependency.app),
      "](vertex://",
      Vertex.id(row.dependency),
      ") | ",
      row.installed,
      " | ",
      row.latest || "—",
      " | ",
      row.standing |> Atom.to_string() |> String.capitalize(),
      " | ",
      case row.advisories do
        [] -> "—"
        advisories -> Enum.map_intersperse(advisories, "; ", &advisory_cell(&1, row.installed))
      end,
      " |\n"
    ]
  end

  # The advisory, its CVE, and what fixes it.
  @spec advisory_cell(Advisory.t(), String.t()) :: iodata()
  defp advisory_cell(advisory, installed) do
    [
      "[",
      advisory.id,
      "](vertex://",
      Util.id(Vertex.Advisory, [advisory.id]),
      ")",
      case Advisory.cve(advisory) do
        nil -> []
        _cve -> [" · ", cve_link(advisory)]
      end,
      case Advisory.fixed_version(advisory, installed) do
        nil -> " · no fix yet"
        fixed -> [" · fixed in ", fixed]
      end
    ]
  end

  # A CVE always links to its record at the CNA that assigned it.
  @spec cve_link(Advisory.t()) :: iodata()
  defp cve_link(advisory) do
    case {Advisory.cve(advisory), Advisory.cve_url(advisory)} do
      {nil, _url} -> "—"
      {cve, nil} -> cve
      {cve, url} -> ["[", cve, "](", url, ")"]
    end
  end

  @spec count_noun(non_neg_integer(), String.t(), String.t()) :: String.t()
  defp count_noun(1, singular, _plural), do: "1 #{singular}"
  defp count_noun(count, _singular, plural), do: "#{count} #{plural}"

  @spec advisory_row(Advisory.t(), String.t()) :: iodata()
  defp advisory_row(advisory, installed) do
    [
      "| [",
      advisory.id,
      "](vertex://",
      Util.id(Vertex.Advisory, [advisory.id]),
      ") | ",
      cve_link(advisory),
      " | ",
      advisory.severity || "—",
      " | ",
      Advisory.fixed_version(advisory, installed) || "—",
      " | ",
      advisory.summary || "",
      " |\n"
    ]
  end

  @spec advisory_markdown(Advisory.t(), String.t() | nil) :: iodata()
  defp advisory_markdown(advisory, installed) do
    [
      "# ",
      advisory.id,
      "\n\n",
      "| Property | Value |\n| --- | --- |\n",
      "| **Package** | `",
      advisory.package,
      "` |\n",
      "| **CVE** | ",
      cve_link(advisory),
      " |\n",
      "| **Severity** | ",
      advisory.severity || "—",
      " |\n",
      if(installed,
        do: ["| **Fixed in** | ", Advisory.fixed_version(advisory, installed) || "—", " |\n"],
        else: []
      ),
      case advisory.aliases |> List.wrap() |> List.delete(Advisory.cve(advisory)) do
        [] -> []
        aliases -> ["| **Aliases** | ", Enum.map_join(aliases, ", ", &alias_link/1), " |\n"]
      end,
      "\n",
      case advisory.summary do
        nil -> []
        summary -> [summary, "\n\n"]
      end,
      references_section(advisory.references)
    ]
  end

  # GitHub's advisories are published at their id.
  @spec alias_link(String.t()) :: String.t()
  defp alias_link("GHSA-" <> _rest = id), do: "[#{id}](https://github.com/advisories/#{id})"
  defp alias_link(id), do: "`#{id}`"

  @spec references_section([String.t()]) :: iodata()
  defp references_section([]), do: []

  defp references_section(references) do
    ["## References\n\n", Enum.map(references, &["- <", &1, ">\n"]), "\n"]
  end

  @spec freshness(DateTime.t() | nil) :: {:at, DateTime.t()} | :never
  defp freshness(nil), do: :never
  defp freshness(%DateTime{} = at), do: {:at, at}

  @spec format_refreshed(DateTime.t()) :: String.t()
  defp format_refreshed(at), do: Calendar.strftime(at, "%-d %B %Y at %-I:%M %p UTC")

  @spec installed_version(String.t()) :: String.t() | nil
  defp installed_version(package) do
    case Application.spec(app_atom(package), :vsn) do
      nil -> nil
      vsn -> to_string(vsn)
    end
  end

  @spec app_atom(String.t()) :: atom() | nil
  defp app_atom(package) do
    String.to_existing_atom(package)
  rescue
    ArgumentError -> nil
  end

  @spec build_update(atom() | nil, String.t()) ::
          %{app: atom(), requirement: String.t() | nil, label: String.t()} | nil
  defp build_update(nil, _installed), do: nil

  defp build_update(app, installed) do
    advisories =
      Enum.filter(Source.advisories_for(app, installed), &Advisory.fixed_version(&1, installed))

    with [_ | _] <- advisories,
         %{latest: latest} <- Registry.summary(app),
         status = Dependency.update_status(installed, latest, Constraints.requirement(app)),
         true <- updatable?(status) do
      count = length(advisories)
      noun = if count == 1, do: "advisory", else: "advisories"

      %{
        app: app,
        requirement: Dependency.widen_requirement(status),
        label: "Update #{app} to #{latest} — resolves #{count} #{noun}"
      }
    else
      _other -> nil
    end
  end

  # Updates are a dev-time affordance, hidden where Mix isn't available (e.g. a
  # release). The actual safety gate lives in Clarity.Dependency.Updater.
  @spec updatable?(Dependency.update_status()) :: boolean()
  defp updatable?(status) do
    mix_available?() and
      case status do
        {:updatable, _latest} -> true
        {:unconstrained, _latest} -> true
        {:constraint_blocks, _latest, _req} -> can_widen?()
        :up_to_date -> false
      end
  end

  @spec can_widen?() :: boolean()
  defp can_widen?, do: Code.ensure_loaded?(Mix.Tasks.Clarity.UpdateDep)

  @spec mix_available?() :: boolean()
  defp mix_available?, do: Code.ensure_loaded?(Mix)
end
