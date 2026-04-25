with {:module, Spark} <- Code.ensure_loaded(Spark) do
  defmodule Clarity.Content.Spark.ExtensionDiagram do
    @moduledoc """
    D2 diagram of a Spark extension's DSL structure.

    Renders the section/entity tree as nested D2 containers. Sections
    become packages, entities become rectangles. Section labels include
    the section name; entity labels include the entity name and target
    module short name.
    """

    @behaviour Clarity.Content

    alias Clarity.Content.D2.Helpers
    alias Clarity.Vertex.Spark.Extension

    @impl Clarity.Content
    def name, do: "DSL Diagram"

    @impl Clarity.Content
    def description, do: "Visual map of this Spark extension's DSL sections and entities"

    @impl Clarity.Content
    def sort_priority, do: -50

    @impl Clarity.Content
    def applies?(%Extension{extension: extension}, _lens) do
      function_exported?(extension, :sections, 0)
    end

    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Extension{extension: extension}, _lens) do
      {:d2, fn _props -> to_d2(extension) end}
    end

    @spec to_d2(module()) :: iodata()
    defp to_d2(extension) do
      sections = extension.sections() || []

      [
        "direction: down\n",
        Helpers.safe_id(inspect(extension)),
        ": ",
        Helpers.quoted(Helpers.short_name(extension)),
        " {\n",
        "  shape: package\n",
        Enum.map(sections, &section_block(&1, "  ")),
        "}\n"
      ]
    end

    @spec section_block(struct(), String.t()) :: iodata()
    defp section_block(section, indent) do
      id = Helpers.safe_id(Atom.to_string(section.name))
      child_indent = indent <> "  "

      [
        indent,
        id,
        ": ",
        Helpers.quoted(Atom.to_string(section.name)),
        " {\n",
        indent,
        "  shape: package\n",
        Enum.map(Map.get(section, :entities, []) || [], &entity_block(&1, child_indent)),
        Enum.map(Map.get(section, :sections, []) || [], &section_block(&1, child_indent)),
        indent,
        "}\n"
      ]
    end

    @spec entity_block(struct(), String.t()) :: iodata()
    defp entity_block(entity, indent) do
      id = Helpers.safe_id(Atom.to_string(entity.name))
      target = Map.get(entity, :target)

      label =
        case target do
          nil -> Atom.to_string(entity.name)
          mod when is_atom(mod) -> Atom.to_string(entity.name) <> "\n" <> Helpers.short_name(mod)
          _ -> Atom.to_string(entity.name)
        end

      [
        indent,
        id,
        ": ",
        Helpers.quoted(label),
        " { shape: rectangle }\n"
      ]
    end
  end
end
