with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.ApplicationDiagramD2 do
    @moduledoc """
    D2 variant of the Application Diagram.

    Renders all Ash resources in an OTP application as D2 nodes grouped
    inside per-domain containers. Mirrors the Graphviz variant
    (`Clarity.Content.Ash.ApplicationDiagram`) so designers can compare the
    two side by side.
    """

    @behaviour Clarity.Content

    alias Clarity.Content.D2.Helpers
    alias Clarity.Vertex.Application
    alias Clarity.Vertex.Ash.Resource

    @impl Clarity.Content
    def name, do: "Application Diagram (D2)"

    @impl Clarity.Content
    def description, do: "D2 visual map of all Ash resources, grouped by domain"

    @impl Clarity.Content
    def sort_priority, do: -85

    @impl Clarity.Content
    def applies?(%Application{app: app}, _lens) do
      Ash.Info.domains(app) != []
    end

    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Application{app: app}, _lens) do
      {:d2, fn %{theme: theme} -> to_d2(app, theme) end}
    end

    @spec to_d2(atom(), Helpers.theme()) :: iodata()
    defp to_d2(app, theme) when is_atom(app) do
      domains_and_resources = Ash.Info.domains_and_resources(app)
      indexed = Enum.with_index(domains_and_resources)

      [
        "direction: down\n",
        Enum.map(indexed, &domain_container(&1, theme))
      ]
    end

    @spec domain_container({{module(), [module()]}, non_neg_integer()}, Helpers.theme()) ::
            iodata()
    defp domain_container({{domain, resources}, idx}, theme) do
      {fill, stroke, fg} = Helpers.domain_palette(idx, theme)
      domain_id = Helpers.safe_id(inspect(domain))

      [
        domain_id,
        ": ",
        Helpers.quoted(inspect(domain)),
        " {\n",
        "  shape: package\n",
        "  style: { fill: \"",
        fill,
        "\"; stroke: \"",
        stroke,
        "\"; font-color: \"",
        fg,
        "\" }\n",
        Enum.map(resources, &resource_node(&1, theme)),
        "}\n"
      ]
    end

    @spec resource_node(module(), Helpers.theme()) :: iodata()
    defp resource_node(resource, theme) do
      {bg, fg, stroke} = Helpers.neutral_palette(theme)
      id = Helpers.safe_id(inspect(resource))

      [
        "  ",
        id,
        ": ",
        Helpers.quoted(Helpers.short_name(resource)),
        " {\n",
        "    shape: rectangle\n",
        "    link: \"",
        Helpers.vertex_link(Resource, [resource]),
        "\"\n",
        "    style: { fill: \"",
        bg,
        "\"; stroke: \"",
        stroke,
        "\"; font-color: \"",
        fg,
        "\" }\n",
        "  }\n"
      ]
    end
  end
end
