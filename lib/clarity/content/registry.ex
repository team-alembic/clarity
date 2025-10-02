defmodule Clarity.Content.Registry do
  @moduledoc """
  Discovers and manages content providers for vertices.

  The Registry scans all loaded applications for `:clarity_content_providers`
  configuration and determines which content should be displayed for a given
  vertex and lens combination.

  ## Configuration

  Content provider configuration is managed by `Clarity.Config`. See the documentation
  for `Clarity.Config` for detailed configuration options and examples.
  """

  alias Clarity.Content
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex

  @doc """
  Gets all applicable content for the given vertex and lens.

  Returns a list of Content structs sorted by the lens's content sorter function.
  """
  @spec get_contents_for_vertex(Vertex.t(), Lens.t()) :: [Content.t()]
  def get_contents_for_vertex(vertex, lens) do
    Clarity.Config.list_content_providers()
    |> Enum.filter(&applies?(&1, vertex, lens))
    |> Enum.map(&build_content_struct(&1, vertex, lens))
    |> Enum.sort(lens.content_sorter)
  end

  @spec applies?(module(), Vertex.t(), Lens.t()) :: boolean()
  defp applies?(provider, vertex, lens) do
    case Code.ensure_loaded(provider) do
      {:module, ^provider} ->
        if function_exported?(provider, :applies?, 2) do
          provider.applies?(vertex, lens)
        else
          false
        end

      _ ->
        false
    end
  end

  @spec build_content_struct(module(), Vertex.t(), Lens.t()) :: Content.t()
  defp build_content_struct(provider, vertex, lens) do
    live_view? = implements_behaviour?(provider, Phoenix.LiveView)
    live_component? = implements_behaviour?(provider, Phoenix.LiveComponent)

    render_static = normalize_static_content(provider.render_static(vertex, lens))

    %Content{
      id: content_id(provider),
      name: provider.name(),
      description: if(function_exported?(provider, :description, 0), do: provider.description()),
      provider: provider,
      live_view?: live_view?,
      live_component?: live_component?,
      render_static: render_static
    }
  end

  @spec normalize_static_content(Content.static_content()) :: Content.rendered_static_content()
  defp normalize_static_content({type, content}) when is_binary(content) or is_list(content) do
    {type, fn _props -> content end}
  end

  defp normalize_static_content({type, content}) when is_function(content, 1) do
    {type, content}
  end

  @spec content_id(module()) :: String.t()
  defp content_id(provider) do
    provider
    |> Macro.underscore()
    |> String.replace(~r/[_\/]+/, "-")
    |> String.replace_prefix("clarity-content-", "")
  end

  @spec implements_behaviour?(module(), module()) :: boolean()
  defp implements_behaviour?(module, behaviour) do
    {:module, ^module} = Code.ensure_loaded(module)

    :attributes
    |> module.module_info()
    |> Keyword.get_values(:behaviour)
    |> Enum.concat()
    |> Enum.member?(behaviour)
  end
end
