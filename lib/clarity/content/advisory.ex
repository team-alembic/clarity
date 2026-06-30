defmodule Clarity.Content.Advisory do
  @moduledoc """
  Security-lens content for dependency advisories.

  On an `Application` vertex it lists the advisories affecting the installed
  version (with the version that fixes each); on an `Advisory` vertex it shows
  the advisory detail. When a released fix is installable, it offers the shared
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
  alias Clarity.Dependency.Registry
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

  @impl Phoenix.LiveComponent
  def update(%{vertex: %Vertex.Application{app: app, version: version}} = assigns, socket) do
    installed = to_string(version)

    {:ok,
     assign(socket,
       prefix: assigns.prefix,
       lens: assigns.lens,
       markdown: application_markdown(app, installed),
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
          "No known advisories for `#{app}` #{installed}.\n\n"

        _present ->
          [
            "| Advisory | Severity | Fixed in | Summary |\n| --- | --- | --- | --- |\n",
            Enum.map(advisories, &advisory_row(&1, installed)),
            "\n"
          ]
      end
    ]
  end

  @spec advisory_row(Advisory.t(), String.t()) :: iodata()
  defp advisory_row(advisory, installed) do
    [
      "| [",
      advisory.id,
      "](vertex://",
      Util.id(Vertex.Advisory, [advisory.id]),
      ") | ",
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
      "| **Severity** | ",
      advisory.severity || "—",
      " |\n",
      if(installed,
        do: ["| **Fixed in** | ", Advisory.fixed_version(advisory, installed) || "—", " |\n"],
        else: []
      ),
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
