defmodule Clarity.Ash.ResourceGroups do
  @moduledoc """
  Groups a domain's resources by the modules they're nested under, so a
  domain of many resources reads as a few families rather than one long list.

  Each resource is named within the domain (`Clarity.Vertex.Name.within/2`):
  `Book.Edition` in `Acme.Library`. Then:

    * An ending that three or more resources share under different modules,
      such as a `Snapshot` kept beside each resource it records, gathers them
      in a group of its own, each named by what it ends (`Book` for
      `Book.Snapshot`).
    * Of the rest, those nested under the same first module form a group named
      after it, each named within it (`Edition`). The module leads its group
      when it's a resource too; when it isn't (a module that only namespaces
      them), the group has no lead, and needs two members.
    * Any other resource stands alone.

  Resources that stand alone come first, then the groups by name, then the
  groups of shared endings.

  ## Examples

      iex> Clarity.Ash.ResourceGroups.group(
      ...>   [Acme.Library.Book, Acme.Library.Book.Edition],
      ...>   Acme.Library
      ...> )
      [
        {:group,
         %{
           kind: :module,
           name: "Book",
           lead: Acme.Library.Book,
           members: [{Acme.Library.Book, "Book"}, {Acme.Library.Book.Edition, "Edition"}]
         }}
      ]
  """

  alias Clarity.Vertex.Name

  @typedoc "A resource, and its name within its group."
  @type member() :: {module(), String.t()}

  @type group() :: %{
          kind: :module | :end,
          name: String.t(),
          lead: module() | nil,
          members: [member()]
        }

  @type entry() :: {:resource, module(), String.t()} | {:group, group()}

  # How many modules must share an ending for it to gather its resources.
  @shared_ending 3

  @doc """
  Groups `resources`, named within `domain`. See the moduledoc.
  """
  @spec group([module()], module()) :: [entry()]
  def group(resources, domain) do
    named = Enum.map(resources, &{&1, &1 |> Name.within(domain) |> String.split(".")})
    endings = shared_endings(named)

    {ending, rest} = Enum.split_with(named, fn {_resource, path} -> ending(path) in endings end)
    {grouped, alone} = module_groups(rest)

    Enum.sort_by(alone, &elem(&1, 2)) ++
      Enum.map(grouped, &{:group, &1}) ++
      Enum.map(ending_groups(ending, endings), &{:group, &1})
  end

  # Endings that three or more nested resources share under different modules.
  @spec shared_endings([{module(), [String.t()]}]) :: [String.t()]
  defp shared_endings(named) do
    named
    |> Enum.filter(fn {_resource, path} -> length(path) > 1 end)
    |> Enum.group_by(fn {_resource, path} -> List.last(path) end, &Enum.drop(elem(&1, 1), -1))
    |> Enum.filter(fn {_ending, parents} -> length(Enum.uniq(parents)) >= @shared_ending end)
    |> Enum.map(&elem(&1, 0))
  end

  @spec ending([String.t()]) :: String.t() | nil
  defp ending([_only]), do: nil
  defp ending(path), do: List.last(path)

  @spec ending_groups([{module(), [String.t()]}], [String.t()]) :: [group()]
  defp ending_groups(named, endings) do
    for ending <- Enum.sort(endings) do
      members =
        for {resource, path} <- named, List.last(path) == ending do
          {resource, path |> Enum.drop(-1) |> Enum.join(".")}
        end

      %{kind: :end, name: ending, lead: nil, members: Enum.sort_by(members, &elem(&1, 1))}
    end
  end

  # Groups by first module, and the resources that stand alone.
  @spec module_groups([{module(), [String.t()]}]) ::
          {[group()], [{:resource, module(), String.t()}]}
  defp module_groups(named) do
    named
    |> Enum.group_by(fn {_resource, [first | _rest]} -> first end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reduce({[], []}, fn {name, family}, {groups, alone} ->
      {leads, nested} = Enum.split_with(family, fn {_resource, path} -> path == [name] end)

      case {leads, nested} do
        {_leads, []} ->
          {groups, alone ++ Enum.map(leads, &standing_alone/1)}

        {[], [single]} ->
          {groups, [standing_alone(single) | alone]}

        {leads, nested} ->
          {[module_group(name, leads, nested) | groups], alone}
      end
    end)
    |> then(fn {groups, alone} -> {Enum.reverse(groups), alone} end)
  end

  @spec module_group(String.t(), [{module(), [String.t()]}], [{module(), [String.t()]}]) ::
          group()
  defp module_group(name, leads, nested) do
    lead = Enum.map(leads, fn {resource, _path} -> {resource, name} end)

    members =
      nested
      |> Enum.map(fn {resource, [_first | rest]} -> {resource, Enum.join(rest, ".")} end)
      |> Enum.sort_by(&elem(&1, 1))

    %{
      kind: :module,
      name: name,
      lead: Enum.find_value(lead, &elem(&1, 0)),
      members: lead ++ members
    }
  end

  @spec standing_alone({module(), [String.t()]}) :: {:resource, module(), String.t()}
  defp standing_alone({resource, path}), do: {:resource, resource, Enum.join(path, ".")}
end
