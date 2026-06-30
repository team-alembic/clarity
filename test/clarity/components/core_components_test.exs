defmodule Clarity.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.Content
  alias Clarity.CoreComponents
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex.Root

  defp content(id, name, status_classes) do
    %Content{
      id: id,
      name: name,
      provider: __MODULE__,
      live_view?: false,
      live_component?: false,
      status_classes: status_classes
    }
  end

  defp tabs(vertex_status_classes) do
    render_component(&CoreComponents.tabs/1,
      contents: [content("overview", "Overview", []), content("version", "Version Status", [:hygiene])],
      content: nil,
      prefix: "/c",
      lens: %Lens{id: "security", name: "Security", icon: fn -> nil end, filter: true},
      vertex: %Root{},
      vertex_status_classes: vertex_status_classes
    )
  end

  describe "tabs/1 status dots" do
    test "flags the tab whose class the vertex carries" do
      html = tabs(%{hygiene: :info})

      assert html =~ "bg-blue-500"
    end

    test "shows no dot when the vertex carries no surfaced status" do
      html = tabs(%{})

      refute html =~ "bg-blue-500"
      refute html =~ "bg-red-500"
      refute html =~ "bg-yellow-500"
    end
  end
end
