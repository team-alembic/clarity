defmodule Clarity.Introspector.ReactorTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Introspector.Reactor, as: ReactorIntrospector
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Action
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Root
  alias Demo.Billing.IssueInvoice
  alias Demo.Billing.Subscription

  describe inspect(&ReactorIntrospector.introspect_vertex/2) do
    test "creates a reactor vertex under the domain whose action runs it" do
      graph = Clarity.Graph.new()
      domain_vertex = %Domain{domain: Demo.Billing}
      Clarity.Graph.add_vertex(graph, domain_vertex, %Root{})
      module_vertex = %Vertex.Module{module: IssueInvoice}

      reactor_vertex = %Vertex.Reactor{reactor: IssueInvoice}

      assert {:ok,
              [
                {:vertex, ^reactor_vertex},
                {:edge, ^domain_vertex, ^reactor_vertex, :reactor},
                {:edge, ^module_vertex, ^reactor_vertex, :reactor}
              ]} = ReactorIntrospector.introspect_vertex(module_vertex, graph)
    end

    test "waits for the reactor's domain before creating its vertex" do
      assert {:error, :unmet_dependencies} =
               ReactorIntrospector.introspect_vertex(
                 %Vertex.Module{module: IssueInvoice},
                 Clarity.Graph.new()
               )
    end

    test "links a domain to the reactors already in the graph that belong to it" do
      graph = Clarity.Graph.new()
      issue_invoice = %Vertex.Reactor{reactor: IssueInvoice}
      Clarity.Graph.add_vertex(graph, issue_invoice, %Root{})

      Clarity.Graph.add_vertex(
        graph,
        %Vertex.Reactor{reactor: Demo.Accounts.OnboardOrganization},
        %Root{}
      )

      domain_vertex = %Domain{domain: Demo.Billing}

      assert {:ok, [{:edge, ^domain_vertex, ^issue_invoice, :reactor}]} =
               ReactorIntrospector.introspect_vertex(domain_vertex, graph)
    end

    test "doesn't link a domain to a reactor twice" do
      graph = Clarity.Graph.new()
      domain_vertex = %Domain{domain: Demo.Billing}
      reactor_vertex = %Vertex.Reactor{reactor: IssueInvoice}
      Clarity.Graph.add_vertex(graph, domain_vertex, %Root{})
      Clarity.Graph.add_vertex(graph, reactor_vertex, domain_vertex)
      Clarity.Graph.add_edge(graph, domain_vertex, reactor_vertex, :reactor)

      assert {:ok, []} = ReactorIntrospector.introspect_vertex(domain_vertex, graph)
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

  describe inspect(&ReactorIntrospector.domain/2) do
    test "is the domain with an action that runs the reactor" do
      assert ReactorIntrospector.domain(IssueInvoice, [Demo.Accounts, Demo.Billing]) == Demo.Billing
    end

    test "is otherwise the domain the reactor's module is named under" do
      assert ReactorIntrospector.domain(Demo.Billing.Unrun, [Demo.Accounts, Demo.Billing]) ==
               Demo.Billing
    end

    test "is nil when no domain runs or names the reactor" do
      assert ReactorIntrospector.domain(IssueInvoice, [Demo.Accounts]) == nil
    end
  end

  @spec action_vertex(atom()) :: Action.t()
  defp action_vertex(name) do
    %Action{action: Info.action(Subscription, name), resource: Subscription}
  end
end
