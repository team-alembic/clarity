defmodule Clarity.Content.Ash.SecurityOverviewTest do
  use ExUnit.Case, async: true

  import Clarity.Test.OverviewHelper

  alias Clarity.Content.Ash.SecurityOverview
  alias Clarity.Perspective.Lensmaker.Architect
  alias Clarity.Perspective.Lensmaker.Security
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource
  alias Demo.Projects.Ticket

  @spec render(Clarity.Vertex.t()) :: LazyHTML.t()
  defp render(vertex), do: render_overview(SecurityOverview, vertex, lens: Security.make_lens())

  describe inspect(&SecurityOverview.applies?/2) do
    test "applies to domains and resources in the Security lens only" do
      assert SecurityOverview.applies?(%Domain{domain: Demo.Projects}, Security.make_lens())
      assert SecurityOverview.applies?(%Resource{resource: Ticket}, Security.make_lens())
      refute SecurityOverview.applies?(%Domain{domain: Demo.Projects}, Architect.make_lens())
    end
  end

  describe "render a domain" do
    test "leads with how many of its resources enforce policies, and its authorisation mode" do
      html = render(%Domain{domain: Demo.Projects})

      assert text(html, ".ov-headline") == "2 of 8 resources enforce policies"
      assert text(html, ".ov-hero .ov-flag") =~ "authorizes by default"
    end

    test "shows resources that enforce no policies first, then those that do, with what each actor reaches" do
      html = render(%Domain{domain: Demo.Projects})

      assert html |> LazyHTML.query(".ov-section") |> Enum.map(&(&1 |> LazyHTML.attribute("id") |> hd())) ==
               ["unprotected", "enforcing"]

      assert "Sprint" in texts(html, "#unprotected .ov-resource-card a.ov-link")
      assert text(html, "#enforcing") =~ "Ticket"
      assert "Anonymous 0/12" in texts(html, "#enforcing .ov-reach-actor")
    end
  end

  describe "render a resource" do
    test "solves who can reach each action, verdict by verdict" do
      html = render(%Resource{resource: Ticket})
      rows = texts(html, "#security-reachability tbody tr")

      assert texts(html, "#security-reachability th") == ["Action", "Anonymous", "User", "API key"]
      assert "read read never conditional conditional" in rows
    end

    test "lists its policies, flagging bypasses" do
      html = render(%Resource{resource: Ticket})

      assert hd(texts(html, "#policies li")) =~ "bypass bypass actor.admin == true"
    end

    test "says so first when nothing enforces policies on it" do
      html = render(%Resource{resource: Demo.Projects.Sprint})

      assert text(html, ".ov-callout") =~ "No policy authorizer."
      assert html |> LazyHTML.query("#security-reachability") |> Enum.empty?()
    end
  end
end
