with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Ash.Provenance do
    @moduledoc """
    Where a calculation's or an aggregate's value comes from: the fields it
    reads, followed down through the calculations and aggregates among them
    to the attributes the data layer stores.

    A calculation reads the fields its expression names (`Clarity.Ash.Expression`),
    or that its module loads or computes from, and those it says to load
    first. An aggregate reads its field at the end of its relationship path,
    and the fields its filter narrows the related records by.

    Each field is followed once: where it comes up again, it's marked as a
    `repeat?` rather than followed again, so the tree is finite even when a
    calculation leads back to itself.
    """

    alias Ash.Resource.Calculation.Context
    alias Clarity.Ash.Expression
    alias Clarity.Vertex
    alias Clarity.Vertex.Ash.Aggregate
    alias Clarity.Vertex.Ash.Calculation
    alias Clarity.Vertex.Ash.Relationship

    @typedoc """
    How a field feeds the one that reads it: named in its expression
    (`:uses`), loaded by its module or before it runs (`:loads`), read by an
    aggregate (`:reads`), or narrowing which records an aggregate reads
    (`:filters`).
    """
    @type role() :: :root | :uses | :loads | :reads | :filters

    @typedoc """
    A field, the relationships followed to it from the field that reads it,
    how it feeds that field, and what it reads in turn.
    """
    @type tree() :: %{
            vertex: Expression.field(),
            via: [Relationship.t()],
            role: role(),
            children: [tree()],
            repeat?: boolean()
          }

    @doc """
    Returns where a calculation's or an aggregate's value comes from, as a
    tree with the field at its root.
    """
    @spec of(Calculation.t() | Aggregate.t()) :: tree()
    def of(vertex) do
      {tree, _seen} = grow(vertex, [], :root, MapSet.new())
      tree
    end

    @doc """
    Returns the fields a field reads directly: each with the relationships
    followed to it and how it feeds the field, once each.
    """
    @spec dependencies(Expression.field()) :: [{Expression.field(), [Relationship.t()], role()}]
    def dependencies(%Calculation{calculation: calculation, resource: resource}) do
      Enum.uniq_by(
        computed_from(resource, calculation) ++ loads(resource, [], calculation.load, :loads),
        fn {field, via, _role} ->
          {Vertex.id(field), Enum.map(via, &Vertex.id/1)}
        end
      )
    end

    def dependencies(%Aggregate{aggregate: aggregate, resource: resource}) do
      {via, destination} = records(resource, aggregate)

      if Enum.member?(via, nil) do
        []
      else
        read =
          case aggregate.field && Expression.field(destination, aggregate.field) do
            nil -> []
            field -> [{field, via, :reads}]
          end

        Enum.uniq_by(
          read ++ filters(destination, via, aggregate) ++ join_filters(resource, aggregate),
          fn {field, via, _role} -> {Vertex.id(field), Enum.map(via, &Vertex.id/1)} end
        )
      end
    end

    def dependencies(_field), do: []

    @doc """
    Returns every field in a tree, each once, and the edges from each field
    to the one that reads it: `{from, to, via, role}`.
    """
    @spec flatten(tree()) ::
            {[Expression.field()],
             [{Expression.field(), Expression.field(), [Relationship.t()], role()}]}
    def flatten(tree) do
      {fields, edges} = collect(tree, {[], []})

      {fields |> Enum.reverse() |> Enum.uniq_by(&Vertex.id/1),
       edges
       |> Enum.reverse()
       |> Enum.uniq_by(fn {from, to, _via, _role} -> {Vertex.id(from), Vertex.id(to)} end)}
    end

    @spec collect(tree(), {list(), list()}) :: {list(), list()}
    defp collect(tree, {fields, edges}) do
      Enum.reduce(tree.children, {[tree.vertex | fields], edges}, fn child, {fields, edges} ->
        collect(child, {fields, [{child.vertex, tree.vertex, child.via, child.role} | edges]})
      end)
    end

    @spec grow(Expression.field(), [Relationship.t()], role(), MapSet.t()) :: {tree(), MapSet.t()}
    defp grow(vertex, via, role, seen) do
      id = Vertex.id(vertex)
      dependencies = dependencies(vertex)
      node = %{vertex: vertex, via: via, role: role, children: [], repeat?: false}

      cond do
        dependencies == [] ->
          {node, seen}

        MapSet.member?(seen, id) ->
          {%{node | repeat?: true}, seen}

        true ->
          {children, seen} =
            Enum.map_reduce(dependencies, MapSet.put(seen, id), fn {field, via, role}, seen ->
              grow(field, via, role, seen)
            end)

          {%{node | children: children}, seen}
      end
    end

    # What a calculation computes its value from: its expression's fields, or
    # its module's.
    @spec computed_from(module(), Ash.Resource.Calculation.t()) :: list()
    defp computed_from(resource, %{calculation: {Ash.Resource.Calculation.Expression, opts}}),
      do: uses(resource, [], Keyword.get(opts, :expr), :uses)

    defp computed_from(resource, %{calculation: {module, opts}} = calculation) do
      context = %Context{
        resource: resource,
        arguments: %{},
        type: calculation.type,
        constraints: calculation.constraints
      }

      uses(resource, [], module_expression(module, opts, context), :uses) ++
        loads(resource, [], module_loads(resource, module, opts, context), :loads)
    end

    defp computed_from(_resource, _calculation), do: []

    # The module's own callbacks, as Ash calls them to plan a query; one
    # that fails says nothing about where the value comes from.
    @spec module_expression(module(), keyword(), map()) :: term()
    defp module_expression(module, opts, context) do
      if Code.ensure_loaded?(module) and function_exported?(module, :has_expression?, 0) and
           module.has_expression?(),
         do: module.expression(opts, context)
    rescue
      _error -> nil
    end

    @spec module_loads(module(), module(), keyword(), map()) :: term()
    defp module_loads(resource, module, opts, context) do
      if Code.ensure_loaded?(module) and function_exported?(module, :load, 3),
        do: module.load(Ash.Query.new(resource), opts, context),
        else: []
    rescue
      _error -> []
    end

    @spec uses(module() | nil, [Relationship.t()], term(), role()) :: list()
    defp uses(_resource, _via, nil, _role), do: []

    defp uses(resource, via, expression, role) do
      for %{via: inner, segments: segments} <- Expression.refs(resource, expression),
          fields = inner ++ Enum.map(segments, &elem(&1, 1)),
          not Enum.member?(fields, nil) do
        {List.last(fields), via ++ Enum.drop(fields, -1), role}
      end
    end

    # What a calculation loads, as Ash's load statements write it: fields,
    # and relationships with what to load from their records.
    @spec loads(module() | nil, [Relationship.t()], term(), role()) :: list()
    defp loads(resource, via, loads, role) do
      loads
      |> List.wrap()
      |> Enum.flat_map(fn
        name when is_atom(name) ->
          field(resource, via, name, role)

        {name, nested} when is_atom(name) ->
          case Expression.field(resource, name) do
            %Relationship{relationship: relationship} = hop ->
              loads(relationship.destination, via ++ [hop], nested, role)

            _field ->
              field(resource, via, name, role)
          end

        _other ->
          []
      end)
    end

    @spec field(module() | nil, [Relationship.t()], atom(), role()) :: list()
    defp field(resource, via, name, role) do
      case Expression.field(resource, name) do
        nil -> []
        field -> [{field, via, role}]
      end
    end

    @spec filters(module() | nil, [Relationship.t()], Ash.Resource.Aggregate.t()) :: list()
    defp filters(destination, via, aggregate),
      do: uses(destination, via, Map.get(aggregate, :filter), :filters)

    @doc """
    Returns where the records an aggregate on `resource` reads are: the
    relationships at the end of its path (`nil` past one the resource
    doesn't have) and the resource there, or the resource it names when it
    isn't related.
    """
    @spec records(module(), Ash.Resource.Aggregate.t()) ::
            {[Relationship.t() | nil], module() | nil}
    def records(_resource, %{related?: false, resource: destination}), do: {[], destination}

    def records(resource, aggregate) do
      {hops, destination} = Expression.follow(resource, aggregate.relationship_path)
      {Enum.map(hops, &elem(&1, 1)), destination}
    end

    # Join filters narrow the records at a step along the aggregate's path.
    @spec join_filters(module(), Ash.Resource.Aggregate.t()) :: list()
    defp join_filters(resource, aggregate) do
      aggregate
      |> Map.get(:join_filters)
      |> Kernel.||([])
      |> Enum.flat_map(fn
        %{relationship_path: path, filter: filter} -> join_filter(resource, path, filter)
        {path, filter} -> join_filter(resource, path, filter)
      end)
    end

    @spec join_filter(module(), [atom()] | atom(), term()) :: list()
    defp join_filter(resource, path, filter) do
      {hops, destination} = Expression.follow(resource, List.wrap(path))
      via = Enum.map(hops, &elem(&1, 1))
      if Enum.member?(via, nil), do: [], else: uses(destination, via, filter, :filters)
    end
  end
end
