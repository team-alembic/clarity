defmodule Clarity.Content.Ash.StateMachinesOverviewTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.Content.Ash.StateMachineDiagram
  alias Clarity.Content.Ash.StateMachinesOverview
  alias Clarity.Perspective.Lensmaker.Architect
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource

  @app %Vertex.Application{app: :clarity, description: "Clarity", version: Version.parse!("0.6.0")}

  describe inspect(&StateMachinesOverview.applies?/2) do
    test "applies to domains and applications with resources that use AshStateMachine" do
      assert StateMachinesOverview.applies?(%Domain{domain: Demo.Billing}, nil)
      assert StateMachinesOverview.applies?(@app, nil)
    end

    test "doesn't apply to domains without any, or to other vertices" do
      refute StateMachinesOverview.applies?(%Domain{domain: Demo.Accounts}, nil)
      refute StateMachinesOverview.applies?(%Resource{resource: Demo.Billing.Invoice}, nil)
    end
  end

  describe "render" do
    test "draws a card per state machine in the domain" do
      cards = cards(%Domain{domain: Demo.Billing})

      assert Enum.map(cards, & &1.title) == ["Billing.Invoice", "Billing.Subscription"]

      for card <- cards, do: assert(card.graph =~ "stateDiagram-v2")
    end

    test "draws every state machine in the application, each linking to its own tab" do
      cards = cards(@app)

      assert Enum.map(cards, & &1.title) == [
               "Billing.Invoice",
               "Billing.Subscription",
               "Helpdesk.Ticket",
               "Projects.Sprint"
             ]

      ticket = Enum.find(cards, &(&1.title == "Helpdesk.Ticket"))
      resource_id = Vertex.id(%Resource{resource: Demo.Helpdesk.Ticket})
      tab_id = Clarity.Content.content_id(StateMachineDiagram)

      assert ticket.href == "/c/architect/#{resource_id}/#{tab_id}"
    end
  end

  @spec cards(Vertex.t()) :: [%{title: String.t(), href: String.t(), graph: String.t()}]
  defp cards(vertex) do
    html =
      render_component(StateMachinesOverview,
        id: "content-view",
        vertex: vertex,
        lens: Architect.make_lens(),
        prefix: "/c"
      )

    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("[data-state-machine]")
    |> Enum.map(fn card ->
      link = LazyHTML.query(card, "a")

      %{
        title: link |> LazyHTML.text() |> String.trim(),
        href: link |> LazyHTML.attribute("href") |> hd(),
        graph: card |> LazyHTML.query("[phx-hook=Mermaid]") |> LazyHTML.attribute("data-graph") |> hd()
      }
    end)
  end
end
