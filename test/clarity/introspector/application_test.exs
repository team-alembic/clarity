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
end
