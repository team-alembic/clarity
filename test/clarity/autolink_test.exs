defmodule Clarity.AutolinkTest do
  use ExUnit.Case, async: true

  alias Clarity.Autolink
  alias Clarity.Graph
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
  alias Demo.Billing.Invoice
  alias Demo.Billing.IssueInvoice
  alias Demo.Helpdesk.Conversation
  alias Demo.Helpdesk.Message
  alias Demo.Helpdesk.Ticket

  @resources [
    Message,
    Conversation,
    Demo.Helpdesk.CustomerContact,
    Ticket,
    Demo.Projects.Ticket,
    Demo.Accounts.User,
    Invoice
  ]

  setup do
    graph = Graph.new()
    for resource <- @resources, do: Graph.add_vertex(graph, %Resource{resource: resource}, %Root{})
    Graph.add_vertex(graph, %Vertex.Reactor{reactor: IssueInvoice}, %Root{})
    Graph.add_vertex(graph, %Domain{domain: Demo.Accounts}, %Root{})
    %{graph: graph}
  end

  describe inspect(&Autolink.names/2) do
    test "names each vertex by its module, its name in the app, and its short name", %{graph: graph} do
      names = Autolink.names(graph, nil)

      assert names["Demo.Helpdesk.Conversation"] == %Resource{resource: Conversation}
      assert names["Helpdesk.Conversation"] == %Resource{resource: Conversation}
      assert names["Conversation"] == %Resource{resource: Conversation}
      assert names["IssueInvoice"] == %Vertex.Reactor{reactor: IssueInvoice}
      assert names["Accounts"] == %Domain{domain: Demo.Accounts}
    end

    test "leaves out a short name two vertices share, unless the context settles it", %{graph: graph} do
      refute Map.has_key?(Autolink.names(graph, %Resource{resource: Invoice}), "Ticket")

      assert Autolink.names(graph, %Resource{resource: Message})["Ticket"] ==
               %Resource{resource: Ticket}
    end

    test "leaves out the vertex the text describes", %{graph: graph} do
      names = Autolink.names(graph, %Resource{resource: Message})

      refute Map.has_key?(names, "Message")
      refute Map.has_key?(names, "Demo.Helpdesk.Message")
    end
  end

  describe inspect(&Autolink.link/3) do
    setup %{graph: graph} do
      %{names: Autolink.names(graph, %Resource{resource: Message})}
    end

    test "links the first mention of each name", %{names: names} do
      html =
        render(
          "A single utterance inside a Conversation, from a User or a CustomerContact. " <>
            "The Conversation belongs to a Ticket.",
          names
        )

      assert html =~ ~s(<a href="/to/Conversation" data-phx-link="patch" data-phx-link-state="push">Conversation</a>)
      assert html =~ ~s(<a href="/to/User")
      assert html =~ ~s(<a href="/to/CustomerContact")
      assert html =~ ~s(<a href="/to/Ticket")
      assert html =~ "The Conversation belongs"
    end

    test "links the longest name a mention spells", %{names: names} do
      html = render("Escalates to Demo.Helpdesk.Ticket, never Projects.Ticket.", names)

      assert html =~ ~s(<a href="/to/Ticket" data-phx-link="patch" data-phx-link-state="push">Demo.Helpdesk.Ticket</a>)
      assert html =~ ~s(<a href="/to/Ticket" data-phx-link="patch" data-phx-link-state="push">Projects.Ticket</a>)
    end

    test "links only whole words", %{names: names} do
      html = render("Users and UserTokens and a Conversations list.", names)

      refute html =~ "<a "
    end

    test "links inline code that is exactly a name, but not headings, links or code blocks", %{
      names: names
    } do
      html =
        render(
          """
          # Conversation

          See [the Conversation docs](https://example.com) and `Demo.Accounts.User`.

          ```
          Conversation
          ```
          """,
          names
        )

      assert html =~
               ~s(<a href="/to/User" data-phx-link="patch" data-phx-link-state="push"><code>Demo.Accounts.User</code></a>)

      refute html =~ ~s(href="/to/Conversation")
    end
  end

  @spec render(String.t(), Autolink.names()) :: String.t()
  defp render(markdown, names) do
    markdown
    |> MDEx.parse_document!()
    |> Autolink.link(names, &("/to/" <> short(&1)))
    |> MDEx.to_html!()
  end

  @spec short(Vertex.t()) :: String.t()
  defp short(vertex), do: vertex |> Vertex.ModuleProvider.module() |> Module.split() |> List.last()
end
