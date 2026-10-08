defmodule Clarity.Content.Ash.ResourceOverviewTest do
  use ExUnit.Case, async: true

  import Clarity.Test.OverviewHelper

  alias Clarity.Content.Ash.ResourceOverview
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User
  alias Demo.Billing.Invoice

  describe inspect(&ResourceOverview.name/0) do
    test "returns resource overview name" do
      assert ResourceOverview.name() == "Resource Overview"
    end
  end

  describe inspect(&ResourceOverview.description/0) do
    test "returns resource overview description" do
      assert ResourceOverview.description() == "Overview of this Ash resource"
    end
  end

  describe inspect(&ResourceOverview.applies?/2) do
    test "returns true for Resource vertices" do
      vertex = %Resource{resource: User}
      lens = nil

      assert ResourceOverview.applies?(vertex, lens) == true
    end

    test "returns false for non-resource vertices" do
      vertex = %Root{}
      lens = nil

      assert ResourceOverview.applies?(vertex, lens) == false
    end
  end

  describe "render" do
    test "leads with the resource's description, data layer, domain and primary key" do
      html = render_overview(ResourceOverview, %Resource{resource: User})

      assert text(html, ".ov-hero .ov-prose") =~ "Identity record"
      assert text(html, ".ov-hero .ov-flag") =~ "multitenant"
      assert html |> texts(".ov-fact dt") |> Enum.take(2) == ["Domain", "Primary key"]
      assert text(html, ".ov-fact dd") =~ "Accounts"
      assert "Ets" in texts(html, ".ov-hero a.ov-pill-link")
    end

    test "lists actions first, by type, flagging the primary ones" do
      html = render_overview(ResourceOverview, %Resource{resource: User})

      assert html |> LazyHTML.query(".ov-section") |> Enum.map(&(&1 |> LazyHTML.attribute("id") |> hd())) |> hd() ==
               "actions"

      assert "READ 5" in texts(html, ".ov-card-title") or "read 5" in texts(html, ".ov-card-title")
      assert text(html, "#actions li") =~ "read primary"
    end

    test "calls out what's notable about each attribute, not columns of true and false" do
      html = render_overview(ResourceOverview, %Resource{resource: Invoice})
      rows = texts(html, "#resource-attributes tbody tr")

      assert Enum.find(rows, &String.starts_with?(&1, "id ")) =~ "primary key"
      assert Enum.find(rows, &String.starts_with?(&1, "status ")) =~ "required default :draft one of draft sent paid"
    end

    test "writes each relationship as a sentence" do
      html = render_overview(ResourceOverview, %Resource{resource: Demo.Projects.Ticket})
      rows = texts(html, "#resource-relationships tbody tr")

      assert Enum.find(rows, &String.starts_with?(&1, "project ")) =~ "belongs to one Project"
      assert Enum.find(rows, &String.starts_with?(&1, "labels ")) =~ "has many Label through TicketLabel"
    end

    test "shows how each aggregate and calculation computes its value" do
      html = render_overview(ResourceOverview, %Resource{resource: Invoice})

      assert text(html, "#resource-aggregates") =~ "sum of line_items.total_cents"
      assert text(html, "#resource-calculations") =~ "if not is_nil(due_on)"
    end
  end
end
