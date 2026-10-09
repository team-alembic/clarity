defmodule Clarity.Pages.LiveViewContentTest do
  # Registers a content provider in the application environment, which every
  # PageLive test reads, so this module can't run alongside them.
  use Clarity.Test.ConnCase, async: false

  alias Clarity.Content
  alias Clarity.Perspective.Lensmaker
  alias Clarity.Vertex

  defmodule SessionProbe do
    @moduledoc false
    @behaviour Content

    use Phoenix.LiveView

    @impl Content
    def name, do: "Session Probe"

    @impl Content
    def description, do: "Shows what a LiveView content provider's session holds"

    @impl Content
    def applies?(_vertex, _lens), do: true

    @impl Phoenix.LiveView
    def mount(_params, session, socket) do
      {:ok, %{vertex: vertex, lens: lens}} = Content.fetch_session(session)
      {:ok, assign(socket, vertex: vertex, lens: lens)}
    end

    @impl Phoenix.LiveView
    def render(assigns) do
      ~H"""
      <div id="session-probe" data-lens={@lens.id} data-vertex={Vertex.id(@vertex)}>
        {@lens.name}
      </div>
      """
    end
  end

  setup do
    original = Application.fetch_env(:clarity, :clarity_content_providers)
    providers = Application.get_env(:clarity, :clarity_content_providers, [])
    Application.put_env(:clarity, :clarity_content_providers, providers ++ [SessionProbe])

    on_exit(fn ->
      case original do
        {:ok, value} -> Application.put_env(:clarity, :clarity_content_providers, value)
        :error -> Application.delete_env(:clarity, :clarity_content_providers)
      end
    end)
  end

  # Every built-in lens carries functions (its icon, its sorter), which a
  # LiveView session can't hold (#113).
  test "mounts a LiveView content provider under every lens that shows it", %{conn: conn} do
    lenses = Enum.filter(Lensmaker.get_all_lenses(), &(SessionProbe in Content.providers_for_lens(&1)))
    assert lenses != []

    for lens <- lenses do
      {:ok, view, _html} = live(conn, "/#{lens.id}/root/#{Content.content_id(SessionProbe)}")

      assert has_element?(
               view,
               "#session-probe[data-lens='#{lens.id}'][data-vertex='root']",
               lens.name
             )
    end
  end

  # Vertices can carry functions too, such as an attribute's default.
  @tag test_graph: [modules: true, attributes: true]
  test "mounts a LiveView content provider for every vertex in the graph", %{
    conn: conn,
    clarity_pid: clarity_pid
  } do
    vertices = Clarity.Graph.vertices(Clarity.get(clarity_pid, :partial).graph)
    assert Enum.any?(vertices, &holds_function?/1)

    for vertex <- vertices do
      vertex_id = Vertex.id(vertex)

      {:ok, view, _html} =
        live(conn, "/debug/#{URI.encode(vertex_id)}/#{Content.content_id(SessionProbe)}")

      assert has_element?(view, "#session-probe[data-vertex='#{vertex_id}']"),
             "no probe for #{vertex_id}"
    end
  end

  @spec holds_function?(term()) :: boolean()
  defp holds_function?(term) do
    term |> :erlang.term_to_binary() |> Plug.Crypto.non_executable_binary_to_term()
    false
  rescue
    ArgumentError -> true
  end
end
