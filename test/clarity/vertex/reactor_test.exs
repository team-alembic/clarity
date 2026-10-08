defmodule Clarity.Vertex.ReactorTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Demo.Billing.IssueInvoice

  describe inspect(&Vertex.Reactor.domain/2) do
    test "is the domain with an action that runs the reactor" do
      assert Vertex.Reactor.domain(IssueInvoice, [Demo.Accounts, Demo.Billing]) == Demo.Billing
    end

    test "is otherwise the domain the reactor's module is named under" do
      assert Vertex.Reactor.domain(Demo.Billing.Unrun, [Demo.Accounts, Demo.Billing]) ==
               Demo.Billing
    end

    test "is nil when no domain runs or names the reactor" do
      assert Vertex.Reactor.domain(IssueInvoice, [Demo.Accounts]) == nil
    end
  end

  describe inspect(&Vertex.Reactor.domain/1) do
    test "looks among the reactor's application's domains" do
      assert Vertex.Reactor.domain(IssueInvoice) == Demo.Billing
      assert Vertex.Reactor.domain(Demo.Accounts.OnboardOrganization) == Demo.Accounts
    end
  end
end
