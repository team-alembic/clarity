with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.DomainOverview do
    @moduledoc """
    Content provider for Ash Domain overview.

    Displays comprehensive information about an Ash domain including its resources.
    """

    @behaviour Clarity.Content

    alias Ash.Domain.Info
    alias Clarity.Vertex.Ash.Domain
    alias Clarity.Vertex.Name
    alias Clarity.Vertex.Util

    @impl Clarity.Content
    def name, do: "Domain Overview"

    @impl Clarity.Content
    def description, do: "Overview of this Ash domain"

    @impl Clarity.Content
    def sort_priority, do: -100

    @impl Clarity.Content
    def applies?(%Domain{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Domain{domain: domain}, _lens) do
      {:markdown,
       fn props -> generate_markdown(domain, Map.get(props, :name_style, :qualified)) end}
    end

    @spec generate_markdown(Ash.Domain.t(), Name.style()) :: iodata()
    defp generate_markdown(domain, name_style) do
      [
        domain_info_section(domain, name_style),
        resources_section(domain, name_style)
      ]
    end

    # With short names, the domain is named within its application, and its
    # resources within it.
    @spec domain_info_section(Ash.Domain.t(), Name.style()) :: iodata()
    defp domain_info_section(domain, name_style) do
      [
        "## Domain Information\n\n",
        "| Property | Value |\n",
        "| --- | --- |\n",
        "| **Domain** | [",
        if(name_style == :short, do: Name.in_app(domain), else: inspect(domain)),
        "](vertex://",
        Util.id(Domain, [domain]),
        ") |\n",
        case get_domain_description(domain) do
          nil -> []
          description -> ["| **Description** | ", clean_description(description), " |\n"]
        end,
        "\n\n"
      ]
    end

    @spec resources_section(Ash.Domain.t(), Name.style()) :: iodata()
    defp resources_section(domain, name_style) do
      resources = Info.resources(domain)

      if Enum.empty?(resources) do
        ["## Resources\n\n", "This domain has no resources defined.\n\n"]
      else
        [
          "## Resources\n\n",
          "| Resource | Description |\n",
          "| --- | --- |\n",
          Enum.map_intersperse(resources, "", &resource_row(&1, domain, name_style)),
          "\n\n"
        ]
      end
    end

    @spec resource_row(Ash.Resource.t(), Ash.Domain.t(), Name.style()) :: iodata()
    defp resource_row(resource, domain, name_style) do
      description = get_resource_description(resource)

      [
        "| [",
        if(name_style == :short, do: Name.within(resource, domain), else: inspect(resource)),
        "](vertex://",
        Util.id(Clarity.Vertex.Ash.Resource, [resource]),
        ") | ",
        clean_description(description),
        " |\n"
      ]
    end

    @spec get_domain_description(Ash.Domain.t()) :: String.t() | nil
    defp get_domain_description(domain) do
      case Code.fetch_docs(domain) do
        {:docs_v1, _annotation, _beam_language, "text/markdown", %{"en" => moduledoc}, _metadata,
         _docs} ->
          extract_first_paragraph(moduledoc)

        _ ->
          nil
      end
    end

    @spec get_resource_description(Ash.Resource.t()) :: String.t() | nil
    defp get_resource_description(resource) do
      case Code.fetch_docs(resource) do
        {:docs_v1, _annotation, _beam_language, "text/markdown", %{"en" => moduledoc}, _metadata,
         _docs} ->
          extract_first_paragraph(moduledoc)

        _ ->
          nil
      end
    end

    @spec extract_first_paragraph(String.t()) :: String.t() | nil
    defp extract_first_paragraph(text) when is_binary(text) do
      text
      |> String.split("\n")
      |> Enum.take_while(&(String.trim(&1) != ""))
      |> Enum.join("\n")
      |> case do
        "" -> nil
        result -> result
      end
    end

    @spec clean_description(String.t() | nil) :: String.t()
    defp clean_description(nil), do: ""

    defp clean_description(description) when is_binary(description) do
      description
      |> String.trim()
      |> String.replace("\n", " ")
      |> String.replace(~r/\s+/, " ")
    end
  end
end
