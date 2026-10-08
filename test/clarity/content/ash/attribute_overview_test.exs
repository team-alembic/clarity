defmodule Clarity.Content.Ash.AttributeOverviewTest do
  use ExUnit.Case, async: true

  import Clarity.Test.OverviewHelper

  alias Ash.Resource.Info
  alias Clarity.Content.Ash.AttributeOverview
  alias Clarity.Vertex.Ash.Attribute
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User
  alias Demo.Projects.Ticket

  describe inspect(&AttributeOverview.name/0) do
    test "returns attribute overview name" do
      assert AttributeOverview.name() == "Attribute Overview"
    end
  end

  describe inspect(&AttributeOverview.description/0) do
    test "returns attribute overview description" do
      assert AttributeOverview.description() == "Overview of this Ash attribute"
    end
  end

  describe inspect(&AttributeOverview.applies?/2) do
    test "returns true for Attribute vertices" do
      [attribute | _] = Info.attributes(User)
      vertex = %Attribute{attribute: attribute, resource: User}
      lens = nil

      assert AttributeOverview.applies?(vertex, lens)
    end

    test "returns false for non-attribute vertices" do
      vertex = %Root{}
      lens = nil

      refute AttributeOverview.applies?(vertex, lens)
    end
  end

  describe "render" do
    test "leads with its type, resource, the values it may take and what's notable" do
      ticket = Ticket
      html = render_overview(AttributeOverview, %Attribute{attribute: Info.attribute(ticket, :status), resource: ticket})

      assert text(html, ".ov-headline") == "atom on Ticket"
      assert text(html, ".ov-hero") =~ "One of open in_progress review closed wont_fix"
      assert text(html, ".ov-hero .ov-flag") =~ "required"
      assert text(html, ".ov-fact") =~ "Default :open"
    end

    test "says where its resource uses it" do
      ticket = Ticket

      html =
        render_overview(AttributeOverview, %Attribute{attribute: Info.attribute(ticket, :project_id), resource: ticket})

      assert text(html, "#used-by") =~ "Key of project"
    end
  end
end
