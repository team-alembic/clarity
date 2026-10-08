defmodule Clarity.Content.Reactor.OverviewTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.Content.Reactor.FlowDiagram
  alias Clarity.Content.Reactor.Overview
  alias Clarity.Perspective.Lensmaker.Architect
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Demo.Billing.IssueInvoice

  @app %Vertex.Application{app: :clarity, description: "Clarity", version: Version.parse!("0.6.0")}

  describe inspect(&Overview.applies?/2) do
    test "applies to applications and domains with Reactors" do
      assert Overview.applies?(@app, nil)
      assert Overview.applies?(%Domain{domain: Demo.Billing}, nil)
    end

    test "doesn't apply to domains without any, or to other vertices" do
      refute Overview.applies?(%Domain{domain: Demo.Projects}, nil)
      refute Overview.applies?(%Vertex.Reactor{reactor: IssueInvoice}, nil)
    end
  end

  describe "render" do
    test "draws a card per Reactor in the domain" do
      assert [%{title: "Billing.IssueInvoice", graph: "flowchart LR" <> _}] =
               cards(%Domain{domain: Demo.Billing})
    end

    test "draws every Reactor in the application, each linking to its own tab" do
      cards = cards(@app)

      assert Enum.map(cards, & &1.title) == ["Accounts.OnboardOrganization", "Billing.IssueInvoice"]

      issue_invoice = Enum.find(cards, &(&1.title == "Billing.IssueInvoice"))
      reactor_id = Vertex.id(%Vertex.Reactor{reactor: IssueInvoice})

      assert issue_invoice.href ==
               "/c/architect/#{reactor_id}/#{Clarity.Content.content_id(FlowDiagram)}"
    end
  end

  @spec cards(Vertex.t()) :: [%{title: String.t(), href: String.t(), graph: String.t()}]
  defp cards(vertex) do
    [id: "content-view", vertex: vertex, lens: Architect.make_lens(), prefix: "/c"]
    |> then(&render_component(Overview, &1))
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("[data-reactor]")
    |> Enum.map(fn card ->
      link = LazyHTML.query(card, "h3 a")

      %{
        title: link |> LazyHTML.text() |> String.trim(),
        href: link |> LazyHTML.attribute("href") |> hd(),
        graph: card |> LazyHTML.query("[phx-hook=Mermaid]") |> LazyHTML.attribute("data-graph") |> hd()
      }
    end)
  end
end
