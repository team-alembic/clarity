with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Introspector.Ash.Domain.OverviewContent do
    @moduledoc false

    alias Ash.Domain.Info
    alias Clarity.Vertex.Content

    @doc false
    @spec generate_content(Ash.Domain.t()) :: Content.t()
    def generate_content(domain) do
      %Content{
        id: "#{inspect(domain)}_overview",
        name: "Domain Overview",
        content: {:markdown, fn -> generate_markdown(domain) end}
      }
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
        "](vertex://domain:",
        inspect(domain),
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
        "](vertex://resource:",
        inspect(resource),
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
