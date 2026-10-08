with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Ash.Expression do
    @moduledoc """
    Reads an Ash expression, as a calculation or an aggregate's filter holds
    it, for the fields it names.

    `parts/2` splits the expression's code, as Ash writes it, into text and
    what it names: each reference to a field, resolved on the resource the
    expression is about, following relationships, `exists/2` and `parent/1`;
    each of the calculation's arguments; and each value from the actor,
    tenant or context. `refs/2` returns just the references.
    """

    alias Ash.Query.Call
    alias Ash.Query.Exists
    alias Ash.Query.Parent
    alias Ash.Query.Ref
    alias Ash.Resource.Info
    alias Clarity.Vertex.Ash.Aggregate
    alias Clarity.Vertex.Ash.Attribute
    alias Clarity.Vertex.Ash.Calculation
    alias Clarity.Vertex.Ash.Relationship

    @typedoc "A field of a resource, as a vertex."
    @type field() :: Attribute.t() | Calculation.t() | Aggregate.t() | Relationship.t()

    @typedoc """
    A reference to a field: each name as written (`project.key`) with the
    relationship or field it names, `nil` where the resource has none; and
    the relationships followed to where the reference sits, such as into
    an `exists/2`.
    """
    @type ref() :: %{via: [Relationship.t()], segments: [{String.t(), field() | nil}]}

    @typedoc """
    A part of an expression's code: text, a reference, one of the
    calculation's arguments, or a value from the actor, tenant or context.
    """
    @type part() :: String.t() | {:ref, ref()} | {:argument, atom()} | {:template, String.t()}

    # Each part's place in the code Ash writes, between two private-use
    # characters, which no expression's own code holds.
    @mark ~r/\x{E000}(\d+)\x{E001}/u

    # Inline aggregates, whose options (a filter, say) are about the related
    # records rather than the expression's own resource.
    @aggregates [:count, :sum, :first, :list, :max, :min, :avg, :exists, :custom_aggregate]

    @doc """
    Splits an expression on `resource` into the parts of its code, as Ash
    writes it.
    """
    @spec parts(module(), term()) :: [part()]
    def parts(resource, expression) do
      {marked, %{parts: parts}} = mark(expression, scope(resource), %{parts: %{}})

      @mark
      |> Regex.split(code(marked), include_captures: true)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn text ->
        case Regex.run(@mark, text, capture: :all_but_first) do
          [index] -> Map.fetch!(parts, String.to_integer(index))
          nil -> text
        end
      end)
    end

    @doc """
    Returns an expression's code, as Ash writes it.
    """
    @spec code(term()) :: String.t()
    def code(expression), do: inspect(expression, pretty: true, width: 80)

    @doc """
    Returns the references to fields in an expression on `resource`, in
    the order they're written.
    """
    @spec refs(module(), term()) :: [ref()]
    def refs(resource, expression) do
      {_marked, %{parts: parts}} = mark(expression, scope(resource), %{parts: %{}})

      parts
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.flat_map(fn
        {_index, {:ref, ref}} -> [ref]
        _other -> []
      end)
    end

    @doc """
    Returns the field `name` of `resource`: an attribute, calculation,
    aggregate or relationship, or `nil` when it has none.
    """
    @spec field(module() | nil, atom() | String.t()) :: field() | nil
    def field(nil, _name), do: nil

    def field(resource, name) do
      cond do
        attribute = Info.attribute(resource, name) ->
          %Attribute{attribute: attribute, resource: resource}

        calculation = Info.calculation(resource, name) ->
          %Calculation{calculation: calculation, resource: resource}

        aggregate = Info.aggregate(resource, name) ->
          %Aggregate{aggregate: aggregate, resource: resource}

        relationship = Info.relationship(resource, name) ->
          %Relationship{relationship: relationship, resource: resource}

        true ->
          nil
      end
    end

    @doc """
    Follows a relationship path from `resource`: each name with the
    relationship it names (`nil` past one the resource doesn't have), and
    the resource at its end.
    """
    @spec follow(module() | nil, [atom() | String.t()]) ::
            {[{String.t(), Relationship.t() | nil}], module() | nil}
    def follow(resource, path) do
      Enum.map_reduce(path, resource, fn name, from ->
        case from && Info.relationship(from, name) do
          nil ->
            {{to_string(name), nil}, nil}

          relationship ->
            {{to_string(name), %Relationship{relationship: relationship, resource: from}},
             relationship.destination}
        end
      end)
    end

    @typep scope() :: %{resource: module() | nil, via: [Relationship.t()], outer: [scope()]}

    @spec scope(module()) :: scope()
    defp scope(resource), do: %{resource: resource, via: [], outer: []}

    # Swaps each part for a mark that Ash writes as it is, keeping the part.
    @spec mark(term(), scope(), map()) :: {term(), map()}
    defp mark(%Ref{attribute: %{name: name}} = ref, scope, acc),
      do: mark(%{ref | attribute: name}, scope, acc)

    defp mark(%Ref{attribute: name, relationship_path: path}, scope, acc)
         when is_atom(name) or is_binary(name),
         do: put({:ref, resolve(scope, path, name)}, acc)

    defp mark(%Exists{related?: true} = exists, scope, acc) do
      at = within(scope, List.wrap(exists.at_path))
      {segments, destination} = follow(at.resource, exists.path)

      {path, acc} =
        Enum.map_reduce(segments, acc, fn segment, acc ->
          {%Ref{attribute: mark}, acc} = put({:ref, %{via: at.via, segments: [segment]}}, acc)
          {mark, acc}
        end)

      inner = %{
        resource: destination,
        via: at.via ++ Enum.map(segments, &elem(&1, 1)),
        outer: [scope | scope.outer]
      }

      {expr, acc} = mark(exists.expr, inner, acc)
      {%{exists | path: path, at_path: [], expr: expr}, acc}
    end

    defp mark(%Exists{related?: false} = exists, scope, acc) do
      {expr, acc} =
        mark(
          exists.expr,
          %{resource: exists.resource, via: [], outer: [scope | scope.outer]},
          acc
        )

      {%{exists | expr: expr}, acc}
    end

    defp mark(%Parent{expr: expr} = parent, scope, acc) do
      {expr, acc} = mark(expr, List.first(scope.outer, scope), acc)
      {%{parent | expr: expr}, acc}
    end

    defp mark(%Call{name: name, args: [%Ref{} = ref | options]} = call, scope, acc)
         when name in @aggregates do
      related = within(scope, ref.relationship_path ++ [Ref.name(ref)])
      {ref, acc} = mark(ref, scope, acc)
      {options, acc} = mark(options, %{related | outer: [scope | scope.outer]}, acc)
      {%{call | args: [ref | options]}, acc}
    end

    defp mark({:_arg, name}, _scope, acc), do: put({:argument, name}, acc)
    defp mark({:_ref, path, name}, scope, acc), do: put({:ref, resolve(scope, path, name)}, acc)
    defp mark({:_actor, field}, _scope, acc), do: put({:template, template(:actor, field)}, acc)
    defp mark({:_context, key}, _scope, acc), do: put({:template, template(:context, key)}, acc)
    defp mark({:_tenant}, _scope, acc), do: put({:template, "^tenant()"}, acc)

    defp mark(%module{} = struct, scope, acc) do
      {fields, acc} =
        struct |> Map.from_struct() |> Enum.map_reduce(acc, &mark_field(&1, scope, &2))

      {struct(module, fields), acc}
    end

    defp mark(map, scope, acc) when is_map(map) do
      {pairs, acc} = Enum.map_reduce(map, acc, &mark_field(&1, scope, &2))
      {Map.new(pairs), acc}
    end

    defp mark(list, scope, acc) when is_list(list),
      do: Enum.map_reduce(list, acc, &mark(&1, scope, &2))

    defp mark(tuple, scope, acc) when is_tuple(tuple) do
      {items, acc} = tuple |> Tuple.to_list() |> mark(scope, acc)
      {List.to_tuple(items), acc}
    end

    defp mark(other, _scope, acc), do: {other, acc}

    @spec mark_field({term(), term()}, scope(), map()) :: {{term(), term()}, map()}
    defp mark_field({key, value}, scope, acc) do
      {value, acc} = mark(value, scope, acc)
      {{key, value}, acc}
    end

    # A ref that Ash writes as the mark itself: the name, with no path.
    @spec put(part(), map()) :: {struct(), map()}
    defp put(part, %{parts: parts} = acc) do
      index = map_size(parts)
      mark = <<0xE000::utf8>> <> Integer.to_string(index) <> <<0xE001::utf8>>
      {%Ref{attribute: mark, relationship_path: []}, %{acc | parts: Map.put(parts, index, part)}}
    end

    @spec resolve(scope(), [atom() | String.t()], atom() | String.t()) :: ref()
    defp resolve(scope, path, name) do
      {segments, resource} = follow(scope.resource, path)
      %{via: scope.via, segments: segments ++ [{to_string(name), field(resource, name)}]}
    end

    # The scope at the end of a relationship path, such as where an inline
    # aggregate's options or an exists's expression are.
    @spec within(scope(), [atom() | String.t()]) :: scope()
    defp within(scope, path) do
      {segments, resource} = follow(scope.resource, path)
      %{scope | resource: resource, via: scope.via ++ Enum.map(segments, &elem(&1, 1))}
    end

    @spec template(atom(), term()) :: String.t()
    defp template(kind, path) when is_list(path),
      do: "^#{kind}(#{Enum.map_join(path, ", ", &inspect/1)})"

    defp template(kind, field), do: "^#{kind}(#{inspect(field)})"
  end
end
