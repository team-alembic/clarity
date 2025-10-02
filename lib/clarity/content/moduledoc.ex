defmodule Clarity.Content.Moduledoc do
  @moduledoc """
  Built-in content provider for module documentation.

  This content provider displays the moduledoc for vertices that have an associated module.
  """

  @behaviour Clarity.Content

  alias Clarity.Vertex

  @impl Clarity.Content
  def name, do: "Module Documentation"

  @impl Clarity.Content
  def description, do: "Documentation for this module"

  @impl Clarity.Content
  def applies?(vertex, _lens) do
    case Vertex.ModuleProvider.module(vertex) do
      nil -> false
      module -> has_moduledoc?(module)
    end
  end

  @impl Clarity.Content
  def render_static(vertex, _lens) do
    module = Vertex.ModuleProvider.module(vertex)
    moduledoc = get_moduledoc(module)
    {:markdown, fn _props -> moduledoc end}
  end

  @spec has_moduledoc?(module()) :: boolean()
  defp has_moduledoc?(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, "text/markdown", %{"en" => _moduledoc}, _, _} -> true
      _ -> false
    end
  end

  @spec get_moduledoc(module()) :: String.t()
  defp get_moduledoc(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, "text/markdown", %{"en" => moduledoc}, _, _} -> moduledoc
      _ -> ""
    end
  end
end
