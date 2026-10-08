defmodule Clarity.Perspective.Lensmaker.GraphNavigation do
  @moduledoc """
  Graph lensmaker: the graph, and nothing else.

  The Graph lens keeps the Debug lens's tree, without framework internals, and
  shows only each vertex's graph, for moving around the graph itself.
  """

  @behaviour Clarity.Perspective.Lensmaker

  import Clarity.IconComponents
  import Phoenix.Component

  alias Clarity.Content
  alias Clarity.Perspective.Lensmaker
  alias Clarity.Perspective.Lensmaker.Debug

  @impl Lensmaker
  def make_lens do
    %{
      Debug.make_lens()
      | id: "graph",
        name: "Graph",
        description: "Shows only each vertex's graph, for moving around it",
        icon: fn ->
          assigns = %{}

          ~H"""
          <.icon_share class="size-full" />
          """
        end,
        show_internals?: false,
        contents: [Content.Graph]
    }
  end
end
