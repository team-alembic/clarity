defmodule Clarity.Ash.ResourceGroupsTest do
  use ExUnit.Case, async: true

  alias Acme.Library, as: L
  alias Acme.Library.Book.Edition
  alias Acme.Library.Book.Review
  alias Clarity.Ash.ResourceGroups

  doctest ResourceGroups

  @domain L

  # The groups as {name, kind, lead, labels}, and ungrouped resources as labels.
  @spec shape([module()]) :: [String.t() | tuple()]
  defp shape(resources) do
    resources
    |> ResourceGroups.group(@domain)
    |> Enum.map(fn
      {:resource, _resource, label} ->
        label

      {:group, group} ->
        {group.name, group.kind, group.lead && inspect(group.lead), Enum.map(group.members, &elem(&1, 1))}
    end)
  end

  test "leaves resources that share no module ungrouped, in order" do
    assert shape([L.Member, L.Branch]) == ["Branch", "Member"]
  end

  test "groups a resource with those nested under it, which it leads" do
    assert shape([L.Book, Edition, Review]) == [
             {"Book", :module, "Acme.Library.Book", ["Book", "Edition", "Review"]}
           ]
  end

  test "groups resources under a module that isn't a resource" do
    assert shape([L.Catalog.Shelf, L.Catalog.Section]) == [
             {"Catalog", :module, nil, ["Section", "Shelf"]}
           ]
  end

  test "names a deeper resource by its path within the group" do
    assert shape([L.Book, Edition, L.Book.Edition.Translation]) == [
             {"Book", :module, "Acme.Library.Book", ["Book", "Edition", "Edition.Translation"]}
           ]
  end

  test "leaves a lone resource under a module that isn't one ungrouped" do
    assert shape([L.Member, L.Events.Reading]) == ["Events.Reading", "Member"]
  end

  test "gathers resources that end the same way under three or more modules, after the rest" do
    resources = [
      L.Branch,
      L.Book,
      Edition,
      L.Book.Snapshot,
      L.Loan,
      L.Loan.Snapshot,
      L.Member,
      L.Member.Card,
      L.Member.Card.Snapshot
    ]

    assert shape(resources) == [
             "Branch",
             "Loan",
             {"Book", :module, "Acme.Library.Book", ["Book", "Edition"]},
             {"Member", :module, "Acme.Library.Member", ["Member", "Card"]},
             {"Snapshot", :end, nil, ["Book", "Loan", "Member.Card"]}
           ]
  end

  test "keeps an ending shared by only two modules in their groups" do
    assert shape([L.Book, Review, L.Branch, L.Branch.Review]) == [
             {"Book", :module, "Acme.Library.Book", ["Book", "Review"]},
             {"Branch", :module, "Acme.Library.Branch", ["Branch", "Review"]}
           ]
  end

  test "groups nothing for no resources" do
    assert ResourceGroups.group([], @domain) == []
  end
end
