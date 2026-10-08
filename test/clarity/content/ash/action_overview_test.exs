defmodule Clarity.Content.Ash.ActionOverviewTest do
  use ExUnit.Case, async: true

  import Clarity.Test.OverviewHelper

  alias Ash.Resource.Info
  alias Clarity.Content.Ash.ActionOverview
  alias Clarity.Vertex.Ash.Action
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User
  alias Demo.Projects.Ticket

  describe inspect(&ActionOverview.name/0) do
    test "returns action overview name" do
      assert ActionOverview.name() == "Action Overview"
    end
  end

  describe inspect(&ActionOverview.description/0) do
    test "returns action overview description" do
      assert ActionOverview.description() == "Overview of this Ash action"
    end
  end

  describe inspect(&ActionOverview.applies?/2) do
    test "returns true for Action vertices" do
      [action | _] = Info.actions(User)
      vertex = %Action{action: action, resource: User}
      lens = nil

      assert ActionOverview.applies?(vertex, lens)
    end

    test "returns false for non-action vertices" do
      vertex = %Root{}
      lens = nil

      refute ActionOverview.applies?(vertex, lens)
    end
  end

  describe "render" do
    test "leads with what the action does, to which resource" do
      ticket = Ticket
      html = render_overview(ActionOverview, %Action{action: Info.action(ticket, :create), resource: ticket})

      assert text(html, ".ov-hero .ov-pill") == "Create action"
      assert text(html, ".ov-hero .ov-flag") =~ "primary"
      assert text(html, ".ov-headline") == "Creates a Ticket"
    end

    test "lists its inputs, with which are required" do
      ticket = Ticket
      html = render_overview(ActionOverview, %Action{action: Info.action(ticket, :create), resource: ticket})
      rows = texts(html, "#action-inputs tbody tr")

      assert Enum.find(rows, &String.starts_with?(&1, "title ")) =~ "required"
      assert Enum.find(rows, &String.starts_with?(&1, "status ")) =~ "one of open in_progress"
    end

    test "lists its steps as calls" do
      ticket = Ticket
      html = render_overview(ActionOverview, %Action{action: Info.action(ticket, :close), resource: ticket})

      assert "change set_attribute(value: :closed, attribute: :status)" in texts(html, ".ov-steps li")
    end

    test "says what a generic action runs and returns" do
      subscription = Demo.Billing.Subscription
      action = Info.action(subscription, :issue_invoice)
      html = render_overview(ActionOverview, %Action{action: action, resource: subscription})

      assert text(html, ".ov-headline") == "Runs on Subscription returning map"
      assert text(html, ".ov-fact") =~ "Runs IssueInvoice"
      assert text(html, "#action-inputs") =~ "subscription_id uuid required argument"
    end
  end
end
