defmodule Clarity.Content.Ash.ApplicationOverviewTest do
  use ExUnit.Case, async: true

  import Clarity.Test.OverviewHelper

  alias Clarity.Content.Ash.ApplicationOverview
  alias Clarity.Vertex.Application
  alias Clarity.Vertex.Root

  describe inspect(&ApplicationOverview.name/0) do
    test "returns application overview name" do
      assert ApplicationOverview.name() == "Application Overview"
    end
  end

  describe inspect(&ApplicationOverview.description/0) do
    test "returns application overview description" do
      assert ApplicationOverview.description() ==
               "Ash domains and resources defined in this application"
    end
  end

  describe inspect(&ApplicationOverview.applies?/2) do
    test "returns true for Application vertex with Ash domains" do
      vertex = %Application{app: :clarity, description: nil, version: "0.2.0"}
      lens = nil

      assert ApplicationOverview.applies?(vertex, lens) == true
    end

    test "returns false for Application vertex without Ash domains" do
      vertex = %Application{app: :kernel, description: nil, version: "10.1"}
      lens = nil

      assert ApplicationOverview.applies?(vertex, lens) == false
    end

    test "returns false for non-Application vertices" do
      vertex = %Root{}
      lens = nil

      assert ApplicationOverview.applies?(vertex, lens) == false
    end
  end

  describe "render" do
    @app %Application{app: :clarity, description: "Clarity", version: Version.parse!("0.2.0")}

    test "leads with the application's version and what it holds" do
      html = render_overview(ApplicationOverview, @app)

      assert text(html, ".ov-fact") =~ "Version 0.2.0"
      assert text(html, ".ov-fact") =~ "Domains"
    end

    test "shows a section for each domain, with a card for each of its resources" do
      html = render_overview(ApplicationOverview, @app, name_style: :short)

      assert "Accounts" in texts(html, ".ov-domain-name")
      assert "User" in texts(html, "#domain-Demo-Accounts .ov-resource-card a.ov-link")
    end
  end
end
