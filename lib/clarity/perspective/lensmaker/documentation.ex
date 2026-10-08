defmodule Clarity.Perspective.Lensmaker.Documentation do
  @moduledoc """
  Documentation lensmaker: the project's documentation, and nothing else.

  The Documentation lens keeps the tree to what carries documentation
  (applications, Ash domains and resources, Phoenix endpoints and routers, and
  modules), over the Architect lens's view of which applications matter, and
  shows only one tab: each module's documentation.
  """

  @behaviour Clarity.Perspective.Lensmaker

  import Clarity.IconComponents
  import Phoenix.Component

  alias Clarity.Content
  alias Clarity.Perspective.Lensmaker
  alias Clarity.Perspective.Lensmaker.Architect
  alias Clarity.Vertex

  @documented_types [
    Vertex.Application,
    Vertex.Ash.Domain,
    Vertex.Ash.Resource,
    Vertex.Phoenix.Endpoint,
    Vertex.Phoenix.Router,
    Vertex.Module
  ]

  @impl Lensmaker
  def make_lens do
    %{
      Architect.make_lens()
      | id: "documentation",
        name: "Documentation",
        description: "Shows each module's documentation",
        icon: fn ->
          assigns = %{}

          ~H"""
          <.icon_book class="size-full" />
          """
        end,
        show_vertex_types: &show_vertex_types/1,
        contents: [Content.Moduledoc]
    }
  end

  @spec show_vertex_types([module()]) :: [module()]
  defp show_vertex_types(available_types),
    do: Enum.filter(available_types, &(&1 in @documented_types))
end
