with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.DomainOverview do
    @moduledoc """
    Content provider for Ash Domain overview.

    Displays comprehensive information about an Ash domain including its resources.
    """

    @behaviour Clarity.Content

    alias Ash.Domain.Info
    alias Clarity.Vertex.Ash.Domain
    alias Clarity.Vertex.Util

    @impl Clarity.Content
    def name, do: "Domain Overview"

    @impl Clarity.Content
    def description, do: "Overview of this Ash domain"

    @impl Clarity.Content
    def applies?(%Domain{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Domain{domain: domain}, _lens) do
      {:markdown, fn _props -> generate_markdown(domain) end}
    end

    @spec generate_markdown(Ash.Domain.t()) :: iodata()
    defp generate_markdown(domain) do
      [
        domain_info_section(domain),
        resources_section(domain)
      ]
    end

    @spec domain_info_section(Ash.Domain.t()) :: iodata()
    defp domain_info_section(domain) do
      [
        "## Domain Information\n\n",
        "| Property | Value |\n",
        "| --- | --- |\n",
        "| **Domain** | [",
        inspect(domain),
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

    @spec resources_section(Ash.Domain.t()) :: iodata()
    defp resources_section(domain) do
      resources = Info.resources(domain)

      if Enum.empty?(resources) do
        ["## Resources\n\n", "This domain has no resources defined.\n\n"]
      else
        [
          "## Resources\n\n",
          "| Resource | Description |\n",
          "| --- | --- |\n",
          resources
          |> Enum.map(&resource_row/1)
          |> Enum.intersperse(""),
          "\n\n"
        ]
      end
    end

    @spec resource_row(Ash.Resource.t()) :: iodata()
    defp resource_row(resource) do
      description = get_resource_description(resource)

      [
        "| [",
        inspect(resource),
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
