defmodule Clarity.Content.Ash.DomainOverviewTest do
  use ExUnit.Case, async: true

  import Clarity.Test.OverviewHelper

  alias Clarity.Content.Ash.DomainOverview
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Root
  alias Demo.Accounts, as: TestDomain

  describe inspect(&DomainOverview.name/0) do
    test "returns domain overview name" do
      assert DomainOverview.name() == "Domain Overview"
    end
  end

  describe inspect(&DomainOverview.description/0) do
    test "returns domain overview description" do
      assert DomainOverview.description() == "Overview of this Ash domain"
    end
  end

  describe inspect(&DomainOverview.applies?/2) do
    test "returns true for Domain vertices" do
      vertex = %Domain{domain: TestDomain}
      lens = nil

      assert DomainOverview.applies?(vertex, lens) == true
    end

    test "returns false for non-domain vertices" do
      vertex = %Root{}
      lens = nil

      assert DomainOverview.applies?(vertex, lens) == false
    end
  end

  describe "render" do
    test "leads with the domain's description and what it holds" do
      html = render_overview(DomainOverview, %Domain{domain: TestDomain})

      assert text(html, ".ov-hero .ov-prose") =~ "Identity and tenancy"
      assert text(html, ".ov-fact") =~ "Resources 6"
    end

    test "gives the domain's full module name, to copy" do
      html = render_overview(DomainOverview, %Domain{domain: TestDomain}, name_style: :short)

      assert html |> texts(".ov-fact dt") |> hd() == "Module"
      assert text(html, ".ov-module code") == "Demo.Accounts"
    end

    test "shows a card for each resource, named within the domain when short" do
      short = render_overview(DomainOverview, %Domain{domain: TestDomain}, name_style: :short)
      qualified = render_overview(DomainOverview, %Domain{domain: TestDomain})

      assert "User" in texts(short, ".ov-resource-card a.ov-link")
      assert "Demo.Accounts.User" in texts(qualified, ".ov-resource-card a.ov-link")
      assert text(short, ".ov-resource-card") =~ "policies"
    end

    test "groups resources nested under the same module, and those that end alike" do
      html = render_overview(DomainOverview, %Domain{domain: Demo.Projects}, name_style: :short)

      assert texts(html, "#resources > .ov-cards .ov-card-name") ==
               ["Attachment", "Comment", "Label", "Project", "Ticket", "TicketLabel", "TimeEntry"]

      assert texts(html, ".ov-resource-group-head") == ["Integration 2", "Sprint 3", "Snapshot 3"]

      assert texts(html, "#resource-group-Sprint .ov-card-name") ==
               ["Sprint", "Goal", "Retrospective"]

      assert texts(html, "#resource-group-Snapshot .ov-card-name") ==
               ["Project", "Sprint", "Ticket"]
    end

    test "leads a group with its module's link when it's a resource" do
      html = render_overview(DomainOverview, %Domain{domain: Demo.Projects}, name_style: :short)

      assert [_link] =
               html
               |> LazyHTML.query(
                 "#resource-group-Sprint .ov-resource-group-head a[data-tooltip-title='Demo.Projects.Sprint']"
               )
               |> Enum.to_list()

      assert html |> LazyHTML.query("#resource-group-Integration .ov-resource-group-head a") |> Enum.empty?()
    end
  end
end
