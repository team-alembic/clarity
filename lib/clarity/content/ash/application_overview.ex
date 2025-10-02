with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.ApplicationOverview do
    @moduledoc """
    Content provider for Application overview in Ash context.

    Displays all Ash domains defined in an application along with their resources.
    """

    @behaviour Clarity.Content

    alias Clarity.Vertex.Application
    alias Clarity.Vertex.Util

    @impl Clarity.Content
    def name, do: "Application Overview"

    @impl Clarity.Content
    def description, do: "Ash domains and resources defined in this application"

    @impl Clarity.Content
    def applies?(%Application{app: app}, _lens) do
      Ash.Info.domains(app) != []
    end

    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Application{app: app}, _lens) do
      {:markdown, fn _props -> generate_markdown(app) end}
    end

    @spec generate_markdown(atom()) :: iodata()
    defp generate_markdown(app) do
      domains_and_resources = Ash.Info.domains_and_resources(app)

      if Enum.empty?(domains_and_resources) do
        ["## Ash Domains\n\n", "This application has no Ash domains defined.\n\n"]
      else
        [
          "## Ash Domains\n\n",
          Enum.map(domains_and_resources, &domain_section/1)
        ]
      end
    end

    @spec domain_section({Ash.Domain.t(), [Ash.Resource.t()]}) :: iodata()
    defp domain_section({domain, resources}) do
      [
        "### [",
        inspect(domain),
        "](vertex://",
        Util.id(Clarity.Vertex.Ash.Domain, [domain]),
        ")\n\n",
        case get_description(domain) do
          nil -> []
          description -> [clean_description(description), "\n\n"]
        end,
        if Enum.empty?(resources) do
          ["_No resources defined_\n\n"]
        else
          [
            "| Resource | Description |\n",
            "| --- | --- |\n",
            Enum.map(resources, &resource_row/1),
            "\n"
          ]
        end
      ]
    end

    @spec resource_row(Ash.Resource.t()) :: iodata()
    defp resource_row(resource) do
      description = get_description(resource)

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

    @spec get_description(module()) :: String.t() | nil
    defp get_description(module) do
      case Code.fetch_docs(module) do
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
