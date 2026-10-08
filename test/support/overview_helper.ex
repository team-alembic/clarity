defmodule Clarity.Test.OverviewHelper do
  @moduledoc false
  # Renders an overview tab's component, as a page would, for tests to query.

  import Phoenix.LiveViewTest

  alias Clarity.Perspective.Lensmaker.Architect

  @doc "Renders `provider`'s component for `vertex`, with any other assigns."
  @spec render_overview(module(), Clarity.Vertex.t(), keyword()) :: LazyHTML.t()
  def render_overview(provider, vertex, assigns \\ []) do
    provider
    |> render_component(
      [id: "overview", vertex: vertex, lens: Architect.make_lens(), prefix: "/c"] ++ assigns
    )
    |> LazyHTML.from_fragment()
  end

  @doc "Returns the text of each element `selector` finds, its whitespace collapsed."
  @spec texts(LazyHTML.t(), String.t()) :: [String.t()]
  def texts(html, selector) do
    html
    |> LazyHTML.query(selector)
    |> Enum.map(&(&1 |> LazyHTML.text() |> String.split() |> Enum.join(" ")))
  end

  @doc "Returns all the text `selector` finds, as one string."
  @spec text(LazyHTML.t(), String.t()) :: String.t()
  def text(html, selector), do: html |> texts(selector) |> Enum.join(" ")
end
