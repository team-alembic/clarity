defmodule Clarity.AutolinkTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Autolink
  alias Clarity.Graph
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Aggregate
  alias Clarity.Vertex.Ash.Attribute
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Relationship
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root
  alias Demo.Accounts.User
  alias Demo.Billing.Invoice
  alias Demo.Billing.IssueInvoice
  alias Demo.Billing.LineItem
  alias Demo.Helpdesk.Conversation
  alias Demo.Helpdesk.CustomerContact
  alias Demo.Helpdesk.Message
  alias Demo.Helpdesk.Ticket
  alias Demo.Projects.Comment
  alias Demo.Projects.Project
  alias Demo.Projects.TimeEntry

  @resources [
    Message,
    Conversation,
    CustomerContact,
    Demo.Helpdesk.SlaPolicy,
    LineItem,
    Ticket,
    Demo.Projects.Ticket,
    User,
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
      refute Map.has_key?(Autolink.names(graph, nil), "Ticket")

      assert Autolink.names(graph, %Resource{resource: Message})["Ticket"] ==
               %Resource{resource: Ticket}
    end

    test "settles a shared name by the text's domain, then by the fewest relationships away", %{graph: graph} do
      # Message isn't related to Helpdesk's Ticket, but shares its domain.
      assert Autolink.names(graph, %Resource{resource: Message})["Ticket"] == %Resource{resource: Ticket}

      # From an Invoice, Helpdesk's Ticket is three relationships away, through
      # its Subscription's Organization; Projects' is four.
      for resource <- [Demo.Billing.Subscription, Demo.Accounts.Organization],
          do: Graph.add_vertex(graph, %Resource{resource: resource}, %Root{})

      assert Autolink.names(graph, %Resource{resource: Invoice})["Ticket"] == %Resource{resource: Ticket}
    end

    test "names a resource after its domain too, as prose does", %{graph: graph} do
      names = Autolink.names(graph, nil)

      assert names["Helpdesk Ticket"] == %Resource{resource: Ticket}
      assert names["Projects Tickets"] == %Resource{resource: Demo.Projects.Ticket}
      assert render("Every Helpdesk Ticket is answered.", names) =~ ~s(>Helpdesk Ticket</a> is answered)
    end

    test "leaves out the vertex the text describes", %{graph: graph} do
      names = Autolink.names(graph, %Resource{resource: Message})

      refute Map.has_key?(names, "Message")
      refute Map.has_key?(names, "Demo.Helpdesk.Message")
    end

    test "reads text about a module as about the domain or resource it defines", %{graph: graph} do
      Graph.add_vertex(graph, %Domain{domain: Demo.Projects}, %Root{})
      Graph.add_vertex(graph, %Resource{resource: Project}, %Root{})

      for vertex <- [%Domain{domain: Demo.Projects}, %Vertex.Module{module: Demo.Projects}] do
        names = Autolink.names(graph, vertex)

        assert names["Projects"] == %Resource{resource: Project}
        assert names["Tickets"] == %Resource{resource: Demo.Projects.Ticket}
      end

      refute Map.has_key?(Autolink.names(graph, %Vertex.Module{module: Message}), "Message")
    end

    test "prefers a vertex's own name to another's plural, as near", %{graph: graph} do
      Graph.add_vertex(graph, %Domain{domain: Demo.Projects}, %Root{})
      Graph.add_vertex(graph, %Resource{resource: Project}, %Root{})

      assert Autolink.names(graph, nil)["Projects"] == %Domain{domain: Demo.Projects}
    end
  end

  describe inspect(&Autolink.link/3) do
    setup %{graph: graph} do
      %{names: Autolink.names(graph, %Resource{resource: Message})}
    end

    test "links each name at its first mention in a paragraph", %{names: names} do
      html =
        render(
          """
          A single utterance inside a Conversation, from a User or a CustomerContact.
          The Conversation belongs to a Ticket.

          Each Conversation has many messages.
          """,
          names
        )

      assert html =~ ~s(<a href="/to/Conversation" data-phx-link="patch" data-phx-link-state="push">Conversation</a>)
      assert html =~ ~s(<a href="/to/User")
      assert html =~ ~s(<a href="/to/CustomerContact")
      assert html =~ ~s(<a href="/to/Ticket")
      assert html =~ "The Conversation belongs"
      assert links(html, "Conversation") == 2
    end

    test "links every mention when asked", %{names: names} do
      html =
        render("A Conversation, from a User, and the Conversation's `Demo.Accounts.User`.", names, &("/to/" <> short(&1)),
          every: true
        )

      assert links(html, "Conversation") == 2
      assert links(html, "User") == 2
    end

    test "reads text under a heading, or in a table row, as about the vertex it links", %{graph: graph} do
      helpdesk = %Domain{domain: Demo.Helpdesk}
      project = %Resource{resource: Project}
      Graph.add_vertex(graph, helpdesk, %Root{})
      Graph.add_vertex(graph, project, %Root{})
      index = Autolink.index(graph)

      html =
        """
        Raises a Ticket.

        ## [Helpdesk](vertex://#{Vertex.id(helpdesk)})

        Raises a Ticket.

        | Resource | Description |
        | --- | --- |
        | [Project](vertex://#{Vertex.id(project)}) | Holds a Ticket. |

        ## Elsewhere

        Raises a Ticket.
        """
        |> MDEx.parse_document!(extension: [table: true])
        |> Autolink.link(Autolink.names_in(index, nil), &field_path/1, index: index)
        |> MDEx.to_html!()

      # Each "a Ticket", in order, with what it links to.
      mentions =
        ~r/a (?:<a href="([^"]*)"[^>]*>)?Ticket/
        |> Regex.scan(html)
        |> Enum.map(fn
          [_mention, href] -> href
          [_mention] -> nil
        end)

      assert mentions == [
               nil,
               "/to/" <> Vertex.id(%Resource{resource: Ticket}),
               "/to/" <> Vertex.id(%Resource{resource: Demo.Projects.Ticket}),
               nil
             ]
    end

    test "links each name at its first mention in a table cell", %{names: names} do
      html = render("| Name | About |\n|---|---|\n| Conversation | Holds a User's Conversation |", names)

      assert links(html, "Conversation") == 2
      assert links(html, "User") == 1
    end

    test "links plurals to the vertex they name", %{names: names} do
      html = render("Invoices, LineItems and SlaPolicies.", names)

      assert html =~ ~s(<a href="/to/Invoice" data-phx-link="patch" data-phx-link-state="push">Invoices</a>)
      assert html =~ ~s(<a href="/to/LineItem" data-phx-link="patch" data-phx-link-state="push">LineItems</a>)
      assert html =~ ~s(<a href="/to/SlaPolicy" data-phx-link="patch" data-phx-link-state="push">SlaPolicies</a>)
    end

    test "links the longest name a mention spells", %{names: names} do
      html = render("Escalates to Demo.Helpdesk.Ticket, never Projects.Ticket.", names)

      assert html =~ ~s(<a href="/to/Ticket" data-phx-link="patch" data-phx-link-state="push">Demo.Helpdesk.Ticket</a>)
      assert html =~ ~s(<a href="/to/Ticket" data-phx-link="patch" data-phx-link-state="push">Projects.Ticket</a>)
    end

    test "copes with thousands of names" do
      names = Map.new(1..5000, &{"Resource#{&1}.some_field_#{&1}", %Resource{resource: Invoice}})

      assert render("See Resource4999.some_field_4999.", names) =~ "<a href="
    end

    test "links a name before a question mark or exclamation", %{names: names} do
      assert render("Is it a Conversation?", names) =~ ~s(>Conversation</a>?)
    end

    test "links only whole words", %{names: names} do
      html = render("UserTokens and Conversational and Invoiced.", names)

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

  describe "fields" do
    setup do
      graph = Graph.new()

      for resource <- [
            Conversation,
            Message,
            Ticket,
            Demo.Projects.Ticket,
            User,
            CustomerContact,
            Invoice,
            LineItem
          ] do
        Graph.add_vertex(graph, %Resource{resource: resource}, %Root{})

        for attribute <- Info.attributes(resource),
            do: Graph.add_vertex(graph, %Attribute{attribute: attribute, resource: resource}, %Root{})

        for aggregate <- Info.aggregates(resource),
            do: Graph.add_vertex(graph, %Aggregate{aggregate: aggregate, resource: resource}, %Root{})
      end

      %{graph: graph}
    end

    test "links a field shared by many resources to the nearest one's", %{graph: graph} do
      names = Autolink.names(graph, %Resource{resource: Conversation})

      assert field(names["status"]) == {Ticket, :status}
      assert field(names[":status"]) == {Ticket, :status}
    end

    test "prefers the text's own resource's field", %{graph: graph} do
      assert field(Autolink.names(graph, %Resource{resource: Invoice})["total_cents"]) ==
               {Invoice, :total_cents}

      assert field(Autolink.names(graph, %Resource{resource: LineItem})["total_cents"]) ==
               {LineItem, :total_cents}
    end

    test "prefers the field of a resource in the text's domain to a related one's", %{graph: graph} do
      assert field(Autolink.names(graph, %Resource{resource: Message})["email"]) == {CustomerContact, :email}
    end

    test "leaves a field unlinked when the nearest resources tie", %{graph: graph} do
      refute Map.has_key?(Autolink.names(graph, nil), "email")
    end

    test "names a field by its resource too", %{graph: graph} do
      names = Autolink.names(graph, nil)

      assert field(names["Invoice.total_cents"]) == {Invoice, :total_cents}
      assert field(names["Billing.Invoice.total_cents"]) == {Invoice, :total_cents}
    end

    test "links a field named after its resource's possessive to that resource's", %{graph: graph} do
      names = Autolink.names(graph, %Resource{resource: LineItem})

      html =
        render("Stored so Invoice's `:total_cents` aggregate sums it, unlike Invoice's status.", names, &field_path/1)

      assert html =~ ~s(href="/to/#{Vertex.id(aggregate(Invoice, :total_cents))}")
      assert html =~ ~s(href="/to/#{Vertex.id(attribute(Invoice, :status))}")
    end

    test "links field names in text only when they look like code", %{graph: graph} do
      names = Autolink.names(graph, %Resource{resource: Conversation})
      html = render("The status and the sla_due_at, or `status`.", names, &field_path/1)

      assert html =~ "The status and"
      assert html =~ ~s(>sla_due_at</a>)
      assert html =~ ~s(<code>status</code></a>)
    end
  end

  describe "lowercase" do
    setup do
      graph = Graph.new()
      Graph.add_vertex(graph, %Domain{domain: Demo.Projects}, %Root{})

      for resource <- [
            Demo.Projects.Ticket,
            Project,
            Comment,
            TimeEntry,
            Demo.Projects.Attachment,
            User,
            Ticket
          ] do
        Graph.add_vertex(graph, %Resource{resource: resource}, %Root{})

        for relationship <- Info.relationships(resource),
            do: Graph.add_vertex(graph, %Relationship{relationship: relationship, resource: resource}, %Root{})
      end

      %{graph: graph}
    end

    test "names resources and domains in lowercase too, only when asked", %{graph: graph} do
      names = Autolink.names(graph, nil, lowercase: true)

      assert names["project"] == %Resource{resource: Project}
      assert names["time entries"] == %Resource{resource: TimeEntry}
      assert names["projects"] == %Domain{domain: Demo.Projects}
      refute Map.has_key?(Autolink.names(graph, nil), "time entries")
    end

    test "prefers a resource to another's field, as near", %{graph: graph} do
      assert Autolink.names(graph, nil, lowercase: true)["user"] == %Resource{resource: User}
    end

    test "links lowercase mentions, written as the names they stand for", %{graph: graph} do
      vertex = %Resource{resource: Comment}
      names = Autolink.names(graph, vertex, lowercase: true)

      html =
        render("Logs time entries against a project, by a user.", names, &field_path/1, lowercase: true, vertex: vertex)

      assert html =~ ~s(>TimeEntries</a> against)
      assert html =~ ~s(href="/to/#{Vertex.id(%Resource{resource: TimeEntry})}")
      assert html =~ ~s(>Project</a>, by a)
      assert html =~ ~s(>User</a>.)
    end

    test "links lowercase field names in text about their own resource only, before resources", %{graph: graph} do
      ticket = %Resource{resource: Demo.Projects.Ticket}
      text = "Has a reporter, and comments."

      html = render(text, Autolink.names(graph, ticket, lowercase: true), &field_path/1, lowercase: true, vertex: ticket)

      assert html =~ ~s(>reporter</a>, and)
      assert html =~ ~s(href="/to/#{Vertex.id(relationship(Demo.Projects.Ticket, :comments))}")

      html =
        render("Logs time entries.", Autolink.names(graph, ticket, lowercase: true), &field_path/1,
          lowercase: true,
          vertex: ticket
        )

      assert html =~ ~s(href="/to/#{Vertex.id(relationship(Demo.Projects.Ticket, :time_entries))}")
      assert html =~ ">time entries</a>."

      user = %Resource{resource: User}
      html = render(text, Autolink.names(graph, user, lowercase: true), &field_path/1, lowercase: true, vertex: user)

      assert html =~ "Has a reporter, and"
      assert html =~ ~s(>Comments</a>.)
    end

    test "leaves a lowercase name as written once its vertex is linked", %{graph: graph} do
      names = Autolink.names(graph, nil, lowercase: true)
      html = render("A TimeEntry, then more time entries.", names, &field_path/1, lowercase: true)

      assert html =~ ">TimeEntry</a>, then more time entries."
    end

    test "leaves lowercase names unlinked unless asked, or when they tie", %{graph: graph} do
      names = Autolink.names(graph, nil, lowercase: true)

      refute render("Logs time entries against a project.", Autolink.names(graph, nil), &field_path/1) =~ "<a "
      refute render("Raises tickets.", names, &field_path/1, lowercase: true) =~ "<a "
    end
  end

  @spec render(String.t(), Autolink.names(), (Vertex.t() -> String.t()), keyword()) :: String.t()
  defp render(markdown, names, path \\ &("/to/" <> short(&1)), opts \\ []) do
    markdown
    |> MDEx.parse_document!(extension: [table: true])
    |> Autolink.link(names, path, opts)
    |> MDEx.to_html!()
  end

  @spec field(Vertex.t() | nil) :: {module(), atom()} | nil
  defp field(%Attribute{attribute: attribute, resource: resource}), do: {resource, attribute.name}
  defp field(%Aggregate{aggregate: aggregate, resource: resource}), do: {resource, aggregate.name}
  defp field(other), do: other

  @spec aggregate(module(), atom()) :: Aggregate.t()
  defp aggregate(resource, name), do: %Aggregate{aggregate: Info.aggregate(resource, name), resource: resource}

  @spec relationship(module(), atom()) :: Relationship.t()
  defp relationship(resource, name),
    do: %Relationship{relationship: Info.relationship(resource, name), resource: resource}

  @spec attribute(module(), atom()) :: Attribute.t()
  defp attribute(resource, name), do: %Attribute{attribute: Info.attribute(resource, name), resource: resource}

  @spec field_path(Vertex.t()) :: String.t()
  defp field_path(vertex), do: "/to/" <> Vertex.id(vertex)

  @spec links(String.t(), String.t()) :: non_neg_integer()
  defp links(html, to), do: length(String.split(html, ~s(href="/to/#{to}"))) - 1

  @spec short(Vertex.t()) :: String.t()
  defp short(vertex), do: vertex |> Vertex.ModuleProvider.module() |> Module.split() |> List.last()
end
