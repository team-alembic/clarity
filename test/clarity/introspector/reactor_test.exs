defmodule Clarity.Introspector.ReactorTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Introspector.Reactor, as: ReactorIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Action
  alias Clarity.Vertex.Root
  alias Demo.Billing.IssueInvoice
  alias Demo.Billing.Subscription

  describe inspect(&ReactorIntrospector.introspect_vertex/2) do
    test "creates a reactor vertex for a module that uses Reactor" do
      graph = Clarity.Graph.new()
      app = Application.get_application(IssueInvoice)
      app_vertex = %Vertex.Application{app: app, description: "", version: "1.0.0"}
      Clarity.Graph.add_vertex(graph, app_vertex, %Root{})
      module_vertex = %Vertex.Module{module: IssueInvoice}

      reactor_vertex = %Vertex.Reactor{reactor: IssueInvoice}

      assert {:ok,
              [
                {:vertex, ^reactor_vertex},
                {:edge, ^app_vertex, ^reactor_vertex, :reactor},
                {:edge, ^module_vertex, ^reactor_vertex, :reactor}
              ]} = ReactorIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "ignores other modules" do
      graph = Clarity.Graph.new()

      assert {:ok, []} =
               ReactorIntrospector.introspect_vertex(%Vertex.Module{module: Subscription}, graph)
    end

    test "links a generic action to the reactor it runs" do
      graph = Clarity.Graph.new()
      reactor_vertex = %Vertex.Reactor{reactor: IssueInvoice}
      Clarity.Graph.add_vertex(graph, reactor_vertex, %Root{})
      action_vertex = action_vertex(:issue_invoice)

      assert {:ok, [{:edge, ^action_vertex, ^reactor_vertex, :reactor}]} =
               ReactorIntrospector.introspect_vertex(action_vertex, graph)
    end

    test "waits for the reactor's vertex before linking an action to it" do
      assert {:error, :unmet_dependencies} =
               ReactorIntrospector.introspect_vertex(action_vertex(:issue_invoice), Clarity.Graph.new())
    end

    test "ignores actions that don't run a reactor" do
      assert {:ok, []} =
               ReactorIntrospector.introspect_vertex(action_vertex(:convert), Clarity.Graph.new())
    end
  end

  @spec action_vertex(atom()) :: Action.t()
  defp action_vertex(name) do
    %Action{action: Info.action(Subscription, name), resource: Subscription}
  end
end
