defmodule Clarity.Introspector.ApplicationTest do
  use ExUnit.Case, async: false

  alias Clarity.Config
  alias Clarity.Introspector.Application, as: ApplicationIntrospector
  alias Clarity.Vertex

  setup do
    original_config = Application.fetch_env(:clarity, :introspector_applications)
    Application.delete_env(:clarity, :introspector_applications)

    on_exit(fn ->
      case original_config do
        {:ok, value} ->
          Application.put_env(:clarity, :introspector_applications, value)

        :error ->
          Application.delete_env(:clarity, :introspector_applications)
      end
    end)

    :ok
  end

  describe inspect(&ApplicationIntrospector.introspect_vertex/2) do
    test "returns application vertices and edges for filtered applications" do
      graph = Clarity.Graph.new()
      root_vertex = %Vertex.Root{}

      {:ok, result} = ApplicationIntrospector.introspect_vertex(root_vertex, graph)

      filtered_apps = Config.filtered_applications()

      # Should return vertices and edges for filtered applications only
      vertices = Enum.filter(result, &match?({:vertex, %Vertex.Application{}}, &1))
      edges = Enum.filter(result, &match?({:edge, _, _, :application}, &1))

      assert length(vertices) == length(filtered_apps)
      assert length(edges) == length(filtered_apps)

      for {:vertex, app_vertex} <- vertices do
        assert %Vertex.Application{} = app_vertex
        assert app_vertex.app in Enum.map(filtered_apps, fn {app, _, _} -> app end)
      end

      for {:edge, from_vertex, to_vertex, :application} <- edges do
        assert from_vertex == root_vertex
        assert %Vertex.Application{} = to_vertex
      end
    end

    test "excludes OTP and Elixir applications by default" do
      filtered_apps = Config.filtered_applications()
      app_names = Enum.map(filtered_apps, fn {app, _, _} -> app end)

      # Should not include common OTP apps
      refute :kernel in app_names
      refute :stdlib in app_names
      refute :sasl in app_names
      refute :crypto in app_names

      # Should not include Elixir apps
      refute :elixir in app_names
      refute :logger in app_names
      refute :mix in app_names
      refute :eex in app_names

      # Should include Clarity itself and other non-OTP/Elixir apps
      assert :clarity in app_names
    end

    test "respects include configuration" do
      Application.put_env(:clarity, :introspector_applications, [:clarity, :phoenix])

      filtered_apps = Config.filtered_applications()
      app_names = Enum.map(filtered_apps, fn {app, _, _} -> app end)

      # Should only include specified apps that are actually loaded
      for app <- app_names do
        assert app in [:clarity, :phoenix]
      end

      # Should include clarity if it's loaded
      if Enum.any?(Application.loaded_applications(), fn {app, _, _} -> app == :clarity end) do
        assert :clarity in app_names
      end
    end
  end

  describe "cache rehydration" do
    test "purges applications that were removed" do
      graph = Clarity.Graph.new()
      root_vertex = %Vertex.Root{}

      # Add root to graph
      Clarity.Graph.add_vertex(graph, root_vertex, root_vertex)

      # Create cached application vertex for an app that doesn't exist in current filtered applications
      cached_app = %Vertex.Application{
        app: :nonexistent_removed_app,
        description: "Removed App",
        version: "1.0.0"
      }

      Clarity.Graph.add_vertex(graph, cached_app, root_vertex)

      {:ok, result} = ApplicationIntrospector.introspect_vertex(root_vertex, graph)

      # Should have purge entry for removed app
      purge_entries = Enum.filter(result, &match?({:purge, %Vertex.Application{}}, &1))

      assert Enum.any?(purge_entries, fn {:purge, vertex} ->
               vertex.app == :nonexistent_removed_app
             end)
    end

    test "purges and re-adds applications with changed versions" do
      graph = Clarity.Graph.new()
      root_vertex = %Vertex.Root{}

      Clarity.Graph.add_vertex(graph, root_vertex, root_vertex)

      # Get current clarity version
      current_filtered = Config.filtered_applications()
      {:clarity, desc, vsn} = Enum.find(current_filtered, fn {app, _, _} -> app == :clarity end)
      current_version = vsn |> to_string() |> Version.parse!()

      # Create cached application with different version
      cached_app = %Vertex.Application{
        app: :clarity,
        description: to_string(desc),
        version: "0.0.1"
      }

      Clarity.Graph.add_vertex(graph, cached_app, root_vertex)

      {:ok, result} = ApplicationIntrospector.introspect_vertex(root_vertex, graph)

      # Should have purge entry for old version
      purge_entries = Enum.filter(result, &match?({:purge, %Vertex.Application{}}, &1))

      assert Enum.any?(purge_entries, fn {:purge, vertex} ->
               vertex.app == :clarity and vertex.version == "0.0.1"
             end)

      # Should have add entry for new version
      add_vertices = Enum.filter(result, &match?({:vertex, %Vertex.Application{}}, &1))

      assert Enum.any?(add_vertices, fn {:vertex, vertex} ->
               vertex.app == :clarity and vertex.version == current_version
             end)
    end

    test "skips applications with unchanged versions" do
      graph = Clarity.Graph.new()
      root_vertex = %Vertex.Root{}

      Clarity.Graph.add_vertex(graph, root_vertex, root_vertex)

      # Get current clarity version
      current_filtered = Config.filtered_applications()
      {:clarity, desc, vsn} = Enum.find(current_filtered, fn {app, _, _} -> app == :clarity end)

      # Create cached application with same version
      cached_app = %Vertex.Application{
        app: :clarity,
        description: to_string(desc),
        version: Version.parse!(to_string(vsn))
      }

      Clarity.Graph.add_vertex(graph, cached_app, root_vertex)

      {:ok, result} = ApplicationIntrospector.introspect_vertex(root_vertex, graph)

      # Should not have purge or add entries for clarity (unchanged)
      clarity_purges =
        Enum.filter(result, fn
          {:purge, %Vertex.Application{app: :clarity}} -> true
          _ -> false
        end)

      clarity_adds =
        Enum.filter(result, fn
          {:vertex, %Vertex.Application{app: :clarity}} -> true
          _ -> false
        end)

      assert clarity_purges == []
      assert clarity_adds == []
    end

    test "adds new applications" do
      graph = Clarity.Graph.new()
      root_vertex = %Vertex.Root{}

      Clarity.Graph.add_vertex(graph, root_vertex, root_vertex)

      # Don't add any cached applications to graph

      {:ok, result} = ApplicationIntrospector.introspect_vertex(root_vertex, graph)

      # All current applications should have add entries
      filtered_apps = Config.filtered_applications()
      add_vertices = Enum.filter(result, &match?({:vertex, %Vertex.Application{}}, &1))

      assert length(add_vertices) == length(filtered_apps)

      # No purge entries since graph was empty
      purge_entries = Enum.filter(result, &match?({:purge, %Vertex.Application{}}, &1))
      assert purge_entries == []
    end
  end
end
