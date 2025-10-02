defmodule Clarity.ContentTest do
  use ExUnit.Case, async: false

  import Phoenix.Component

  alias Clarity.Content
  alias Clarity.Graph.Filter
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex.Root

  defmodule TestContentProvider do
    @moduledoc false
    @behaviour Content

    @impl Content
    def name, do: "Test Content"

    @impl Content
    def description, do: "Test content provider"

    @impl Content
    def applies?(%Root{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Content
    def render_static(_vertex, _lens) do
      {:markdown, "Test content"}
    end
  end

  defmodule TestLiveViewProvider do
    @moduledoc false
    @behaviour Content

    use Phoenix.LiveView

    @impl Content
    def name, do: "Live View Content"

    @impl Content
    def applies?(%Root{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Phoenix.LiveView
    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    @impl Phoenix.LiveView
    def render(assigns) do
      ~H"<div>Test</div>"
    end
  end

  defmodule TestLiveComponentProvider do
    @moduledoc false
    @behaviour Content

    use Phoenix.LiveComponent

    @impl Content
    def name, do: "Live Component Content"

    @impl Content
    def applies?(%Root{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      {:ok, assign(socket, assigns)}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"<div>Test Component</div>"
    end
  end

  defmodule AlwaysFalseProvider do
    @moduledoc false
    @behaviour Content

    @impl Content
    def name, do: "Never Applies"

    @impl Content
    def applies?(_vertex, _lens), do: false

    @impl Content
    def render_static(_vertex, _lens) do
      {:markdown, "Should not see this"}
    end
  end

  describe "get_contents_for_vertex/2" do
    setup do
      original_config = Application.fetch_env(:clarity, :clarity_content_providers)
      Application.delete_env(:clarity, :clarity_content_providers)

      on_exit(fn ->
        case original_config do
          {:ok, value} ->
            Application.put_env(:clarity, :clarity_content_providers, value)

          :error ->
            Application.delete_env(:clarity, :clarity_content_providers)
        end
      end)

      lens = %Lens{
        id: "test",
        name: "Test",
        icon: fn ->
          assigns = %{}
          ~H"🧪"
        end,
        filter: Filter.custom(fn _vertex -> true end),
        content_sorter: &Lens.sort_alphabetically/2
      }

      vertex = %Root{}

      {:ok, lens: lens, vertex: vertex}
    end

    test "returns list of applicable content", %{vertex: vertex, lens: lens} do
      providers = [TestContentProvider, AlwaysFalseProvider]
      Application.put_env(:clarity, :clarity_content_providers, providers)

      contents = Content.get_contents_for_vertex(vertex, lens)

      assert [%Content{provider: TestContentProvider}] = contents
    end

    test "filters out non-applicable content", %{vertex: vertex, lens: lens} do
      providers = [AlwaysFalseProvider]
      Application.put_env(:clarity, :clarity_content_providers, providers)

      contents = Content.get_contents_for_vertex(vertex, lens)
      assert [] = contents
    end

    test "builds content struct with correct fields", %{vertex: vertex, lens: lens} do
      providers = [TestContentProvider]
      Application.put_env(:clarity, :clarity_content_providers, providers)

      [content] = Content.get_contents_for_vertex(vertex, lens)

      assert %Content{
               name: "Test Content",
               description: "Test content provider",
               provider: TestContentProvider,
               live_view?: false,
               live_component?: false,
               render_static: {_, render_fn}
             } = content

      assert is_function(render_fn, 1)
    end

    test "detects LiveView providers", %{vertex: vertex, lens: lens} do
      providers = [TestLiveViewProvider]
      Application.put_env(:clarity, :clarity_content_providers, providers)

      [content] = Content.get_contents_for_vertex(vertex, lens)

      assert %Content{
               live_view?: true,
               live_component?: false,
               render_static: nil
             } = content
    end

    test "detects LiveComponent providers", %{vertex: vertex, lens: lens} do
      providers = [TestLiveComponentProvider]
      Application.put_env(:clarity, :clarity_content_providers, providers)

      [content] = Content.get_contents_for_vertex(vertex, lens)

      assert %Content{
               live_view?: false,
               live_component?: true,
               render_static: nil
             } = content
    end

    test "sorts content using lens content_sorter", %{vertex: vertex} do
      defmodule ZProvider do
        @moduledoc false
        @behaviour Content

        @impl Content
        def name, do: "Z Content"
        @impl Content
        def applies?(%Root{}, _lens), do: true
        def applies?(_vertex, _lens), do: false
        @impl Content
        def render_static(_vertex, _lens), do: {:markdown, "Z"}
      end

      defmodule AProvider do
        @moduledoc false
        @behaviour Content

        @impl Content
        def name, do: "A Content"
        @impl Content
        def applies?(%Root{}, _lens), do: true
        def applies?(_vertex, _lens), do: false
        @impl Content
        def render_static(_vertex, _lens), do: {:markdown, "A"}
      end

      providers = [ZProvider, AProvider]
      Application.put_env(:clarity, :clarity_content_providers, providers)

      lens = %Lens{
        id: "test",
        name: "Test",
        icon: fn ->
          assigns = %{}
          ~H"🧪"
        end,
        filter: Filter.custom(fn _vertex -> true end),
        content_sorter: &Lens.sort_alphabetically/2
      }

      contents = Content.get_contents_for_vertex(vertex, lens)

      assert [
               %Content{name: "A Content"},
               %Content{name: "Z Content"}
             ] = contents
    end

    test "normalizes static content as iodata to function", %{vertex: vertex, lens: lens} do
      providers = [TestContentProvider]
      Application.put_env(:clarity, :clarity_content_providers, providers)

      [content] = Content.get_contents_for_vertex(vertex, lens)

      assert {:markdown, render_fn} = content.render_static
      assert is_function(render_fn, 1)
      assert render_fn.(%{}) == "Test content"
    end

    test "handles providers without description callback", %{vertex: vertex, lens: lens} do
      defmodule NoDescProvider do
        @moduledoc false
        @behaviour Content

        @impl Content
        def name, do: "No Desc"
        @impl Content
        def applies?(%Root{}, _lens), do: true
        def applies?(_vertex, _lens), do: false
        @impl Content
        def render_static(_vertex, _lens), do: {:markdown, "X"}
      end

      providers = [NoDescProvider]
      Application.put_env(:clarity, :clarity_content_providers, providers)

      [content] = Content.get_contents_for_vertex(vertex, lens)
      assert content.description == nil
    end
  end
end
