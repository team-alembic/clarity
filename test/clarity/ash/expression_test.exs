defmodule Clarity.Ash.ExpressionTest do
  use ExUnit.Case, async: true

  import Ash.Expr

  alias Ash.Resource.Info
  alias Clarity.Ash.Expression
  alias Clarity.Vertex.Ash.Aggregate
  alias Clarity.Vertex.Ash.Attribute
  alias Clarity.Vertex.Ash.Relationship
  alias Demo.Accounts.User
  alias Demo.Billing.Invoice
  alias Demo.Projects.Comment
  alias Demo.Projects.Project
  alias Demo.Projects.Sprint
  alias Demo.Projects.Ticket

  # The parts as text, each reference in brackets with what it names.
  @spec written([Expression.part()]) :: String.t()
  defp written(parts) do
    Enum.map_join(parts, fn
      text when is_binary(text) -> text
      {:ref, %{segments: segments}} -> "[" <> Enum.map_join(segments, ".", &segment/1) <> "]"
      {:argument, name} -> "<arg #{name}>"
      {:template, text} -> "<#{text}>"
    end)
  end

  @spec segment({String.t(), Expression.field() | nil}) :: String.t()
  defp segment({name, nil}), do: name <> "?"
  defp segment({name, %{__struct__: struct}}), do: name <> ":" <> (struct |> Module.split() |> List.last())

  @spec expression(module(), atom()) :: term()
  defp expression(resource, name) do
    {_module, opts} = Info.calculation(resource, name).calculation
    opts[:expr]
  end

  describe inspect(&Expression.parts/2) do
    test "splits a calculation's code, as Ash writes it, into text and what it names" do
      assert written(Expression.parts(Ticket, expression(Ticket, :code))) ==
               ~s|fragment("? \|\| '-' \|\| ?",  [project:Relationship.key:Attribute],  [position:Attribute])|
    end

    test "names aggregates, and the calculation's arguments" do
      assert written(Expression.parts(Invoice, expression(Invoice, :outstanding_cents))) =~
               "[total_cents:Aggregate]"

      assert written(Expression.parts(User, expression(User, :multi_arguments))) =~
               ~s|"Arg1: " <> <arg arg1> <> ", Arg2: "|
    end

    test "resolves inside exists on the related resource, and parent back on its own" do
      parts =
        Expression.parts(
          Ticket,
          expr(exists(comments, body == "x" and parent(title) == ^actor(:id)))
        )

      assert written(parts) ==
               ~s|exists([comments:Relationship], ([body:Attribute] == "x") and (parent([title:Attribute]) == <^actor(:id)>))|

      assert [%{via: [], segments: [{"comments", %Relationship{}}]}, %{via: [via], segments: [{"body", body}]}, _title] =
               for({:ref, ref} <- parts, do: ref)

      assert via.relationship.name == :comments
      assert %Attribute{resource: Comment} = body
    end

    test "resolves an inline aggregate's filter on the related records" do
      parts = Expression.parts(Ticket, expr(count(comments, query: [filter: expr(body != "y")]) > 0))

      assert [{:ref, %{segments: [{"comments", %Relationship{}}]}}] =
               Enum.filter(parts, &match?({:ref, %{segments: [{"comments", _}]}}, &1))

      assert [%Attribute{resource: Comment}] =
               for({:ref, %{segments: [{"body", field}]}} <- parts, do: field)
    end

    test "leaves a name the resource doesn't have unresolved" do
      assert written(Expression.parts(Ticket, expr(project.nothing == 1))) =~ "[project:Relationship.nothing?]"
      assert written(Expression.parts(Ticket, expr(nowhere.key == 1))) =~ "[nowhere?.key?]"
    end
  end

  describe inspect(&Expression.refs/2) do
    test "returns the references, in the order they're written" do
      refs = Expression.refs(Sprint, expression(Sprint, :completion_ratio))

      assert Enum.map(refs, fn %{segments: [{name, %Aggregate{}}]} -> name end) ==
               ["ticket_count", "closed_ticket_count", "ticket_count"]
    end
  end

  describe inspect(&Expression.field/2) do
    test "returns the field of any kind, or nil" do
      assert %Attribute{} = Expression.field(Project, :key)
      assert %Aggregate{} = Expression.field(Project, :ticket_count)
      assert %Relationship{} = Expression.field(Project, :tickets)
      assert Expression.field(Project, :nothing) == nil
      assert Expression.field(nil, :key) == nil
    end
  end
end
