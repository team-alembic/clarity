defmodule Clarity.Autolink do
  @moduledoc """
  Links the names of vertices where rendered text mentions them, so a
  description such as "A single utterance inside a Conversation, from a User"
  links Conversation and User to their pages.

  A resource, domain or Reactor is named by its module
  (`Demo.Helpdesk.Conversation`), by its name within the application
  (`Helpdesk.Conversation`) and by its short name (`Conversation`, or
  `Accounts` for a domain), and a resource by its plural too
  (`Conversations`, `Policies`). An attribute, calculation, aggregate,
  relationship or action is named by its name (`total_cents`, `:status`,
  `sensitive?`) and by its resource's name and its own (`Invoice.total_cents`).
  Field names that read as plain words, such as `status`, link only in inline
  code; ones that look like code, such as `total_cents`, link in running text
  too.

  When a name fits more than one vertex, the text's own vertex settles it by
  nearness: its own resource first, then a resource it has a relationship to,
  then one in its domain. Of two as near, the one the name names wins over
  the one it pluralises (`Projects`, the domain, over the Project resource's
  plural); otherwise the name isn't linked. Text about a module is read as
  about the domain or resource the module defines.
  Only whole words link, each vertex at its first mention in a paragraph or
  table cell, and never the vertex the text describes, nor text in a heading,
  a link or a code block.
  """

  alias Ash.Resource.Info
  alias Clarity.Graph
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Action
  alias Clarity.Vertex.Ash.Aggregate
  alias Clarity.Vertex.Ash.Attribute
  alias Clarity.Vertex.Ash.Calculation
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Relationship
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.ModuleProvider

  @typedoc "Names that link, each to the vertex it names."
  @type names() :: %{String.t() => Vertex.t()}

  # The text's vertex's own resource, the resources it relates to, and its domain.
  @typep context() :: %{resource: module() | nil, related: [module()], domain: module() | nil}

  @named_by_module [Resource, Domain, Vertex.Reactor]
  # Vertices for a resource's fields, with the key holding the field.
  @fields %{
    Attribute => :attribute,
    Calculation => :calculation,
    Aggregate => :aggregate,
    Relationship => :relationship,
    Action => :action
  }
  @linkable @named_by_module ++ Map.keys(@fields)

  # Anything in running text that could be a name, whole: a word or dotted
  # name, perhaps after a colon and before a ? or !, not part of a longer one.
  @token ~r/(?<![\w.:'’]):?[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*[?!]?/u
  # Text ending in a name's possessive: "Invoice's ".
  @possessive ~r/(?<![\w.])([A-Z][\w.]*)['’]s\s+$/u

  @doc """
  Returns the names to link in text about `vertex` (or about nothing in
  particular, with `nil`), from the vertices in `graph`.
  """
  @spec names(Graph.t(), Vertex.t() | nil) :: names()
  def names(graph, vertex) do
    context = context(vertex)

    graph
    |> Graph.vertices({:in, :vertex_type, @linkable})
    |> Enum.reject(&described?(&1, vertex))
    |> Enum.flat_map(fn named ->
      Enum.map(spellings(named), &{&1, {named, :name}}) ++
        Enum.map(plurals(named), &{&1, {named, :plural}})
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.flat_map(fn {name, candidates} ->
      case pick(Enum.uniq(candidates), context) do
        nil -> []
        named -> [{name, named}]
      end
    end)
    |> Map.new()
  end

  @doc """
  Links the first mention of each name in an MDEx document, to the path
  `path` gives for its vertex.
  """
  @spec link(MDEx.Document.t(), names(), (Vertex.t() -> String.t())) :: MDEx.Document.t()
  def link(document, names, _path) when map_size(names) == 0, do: document

  def link(document, names, path) do
    {document, _linked} = walk(document, %{names: names, path: path}, MapSet.new())
    document
  end

  @doc """
  Returns nodes that wrap `children` in a link LiveView follows by patching.
  """
  @spec patch_link(String.t(), [MDEx.Document.md_node()], String.t() | nil) ::
          [MDEx.Document.md_node()]
  def patch_link(url, children, title \\ nil) do
    title_attr = if title in [nil, ""], do: "", else: ~s( title="#{escape(title)}")

    # MDEx.Link has no attributes field, so the anchor is raw HTML.
    open = %MDEx.Raw{
      literal:
        ~s(<a href="#{escape(url)}" data-phx-link="patch" data-phx-link-state="push"#{title_attr}>)
    }

    [open | children] ++ [%MDEx.Raw{literal: "</a>"}]
  end

  # Whether `named` is what the text describes: its own vertex, or for text
  # about a module, the domain, resource or Reactor the module defines.
  @spec described?(Vertex.t(), Vertex.t() | nil) :: boolean()
  defp described?(named, named), do: true

  defp described?(%{__struct__: struct} = named, %Vertex.Module{module: module})
       when struct in @named_by_module,
       do: ModuleProvider.module(named) == module

  defp described?(_named, _vertex), do: false

  @spec walk(MDEx.Document.md_node(), map(), MapSet.t()) :: {MDEx.Document.md_node(), MapSet.t()}
  defp walk(%MDEx.Link{} = node, _context, linked), do: {node, linked}
  defp walk(%MDEx.Heading{} = node, _context, linked), do: {node, linked}

  # Each paragraph or table cell links its own first mentions.
  defp walk(%block{nodes: nodes} = node, context, linked)
       when block in [MDEx.Paragraph, MDEx.TableCell] do
    {nodes, _linked} = children(nodes, context, MapSet.new())
    {%{node | nodes: nodes}, linked}
  end

  defp walk(%{nodes: nodes} = node, context, linked) when is_list(nodes) do
    {nodes, linked} = children(nodes, context, linked)
    {%{node | nodes: nodes}, linked}
  end

  defp walk(node, _context, linked), do: {node, linked}

  # Each child, with the name whose possessive the text before it ends in.
  @spec children([MDEx.Document.md_node()], map(), MapSet.t()) ::
          {[MDEx.Document.md_node()], MapSet.t()}
  defp children(nodes, context, linked) do
    nodes
    |> Enum.zip([nil | nodes])
    |> Enum.flat_map_reduce(linked, fn {node, previous}, linked ->
      owner =
        with %MDEx.Text{literal: text} <- previous,
             [_, name] <- Regex.run(@possessive, text) do
          name
        else
          _no_possessive -> nil
        end

      child(node, owner, context, linked)
    end)
  end

  @spec child(MDEx.Document.md_node(), String.t() | nil, map(), MapSet.t()) ::
          {[MDEx.Document.md_node()], MapSet.t()}
  defp child(%MDEx.Text{literal: text}, _owner, context, linked) do
    # Alternates text between tokens and tokens, starting and ending with text.
    pieces = Regex.split(@token, text, include_captures: true)

    pieces
    |> Enum.with_index()
    |> Enum.flat_map_reduce(linked, fn
      {"", _index}, linked ->
        {[], linked}

      {piece, index}, linked when rem(index, 2) == 1 ->
        token(piece, owner(pieces, index), context, linked)

      {piece, _index}, linked ->
        {[%MDEx.Text{literal: piece}], linked}
    end)
  end

  defp child(%MDEx.Code{literal: literal} = code, owner, context, linked) do
    case owned(owner, literal, context) do
      nil -> mention(literal, [code], context, linked)
      vertex -> link_vertex(vertex, [code], context, linked)
    end
  end

  defp child(node, _owner, context, linked) do
    {node, linked} = walk(node, context, linked)
    {[node], linked}
  end

  # The name before the token at `index`, if the token follows its possessive.
  @spec owner([String.t()], non_neg_integer()) :: String.t() | nil
  defp owner(pieces, index) when index >= 2 do
    if String.match?(Enum.at(pieces, index - 1), ~r/^['’]s\s+$/u), do: Enum.at(pieces, index - 2)
  end

  defp owner(_pieces, _index), do: nil

  # "Invoice's total_cents": a field named after its resource's possessive is
  # that resource's, however near another resource's is, and links even when
  # its name is a plain word ("Invoice's status").
  @spec owned(String.t() | nil, String.t(), map()) :: Vertex.t() | nil
  defp owned(nil, _field, _context), do: nil

  defp owned(owner, field, context) do
    case Map.get(context.names, owner) do
      %{__struct__: Resource} ->
        Map.get(context.names, owner <> "." <> String.trim_leading(field, ":"))

      _not_a_resource ->
        nil
    end
  end

  # Links a token of running text that names a vertex. A name may end in ? or
  # ! (sensitive?), so a token ending in one is tried with it, then without.
  @spec token(String.t(), String.t() | nil, map(), MapSet.t()) ::
          {[MDEx.Document.md_node()], MapSet.t()}
  defp token(text, owner, context, linked) do
    trimmed = text |> String.trim_trailing("?") |> String.trim_trailing("!")

    cond do
      vertex = owned(owner, text, context) ->
        link_vertex(vertex, [%MDEx.Text{literal: text}], context, linked)

      prose_name?(text, context) ->
        mention(text, [%MDEx.Text{literal: text}], context, linked)

      trimmed != text and prose_name?(trimmed, context) ->
        {nodes, linked} = mention(trimmed, [%MDEx.Text{literal: trimmed}], context, linked)
        {nodes ++ [%MDEx.Text{literal: String.replace_prefix(text, trimmed, "")}], linked}

      true ->
        {[%MDEx.Text{literal: text}], linked}
    end
  end

  @spec prose_name?(String.t(), map()) :: boolean()
  defp prose_name?(text, context), do: prose?(text) and Map.has_key?(context.names, text)

  # Links `nodes` if `text` names a vertex not yet linked, or leaves them be.
  @spec mention(String.t(), [MDEx.Document.md_node()], map(), MapSet.t()) ::
          {[MDEx.Document.md_node()], MapSet.t()}
  defp mention(text, nodes, context, linked) do
    case Map.fetch(context.names, text) do
      {:ok, vertex} -> link_vertex(vertex, nodes, context, linked)
      :error -> {nodes, linked}
    end
  end

  @spec link_vertex(Vertex.t(), [MDEx.Document.md_node()], map(), MapSet.t()) ::
          {[MDEx.Document.md_node()], MapSet.t()}
  defp link_vertex(vertex, nodes, context, linked) do
    if MapSet.member?(linked, vertex),
      do: {nodes, linked},
      else: {patch_link(context.path.(vertex), nodes), MapSet.put(linked, vertex)}
  end

  # Names that read as names in running text: module-like ones, and field
  # names that look like code. Plain words, such as `status`, link only in
  # inline code.
  @spec prose?(String.t()) :: boolean()
  defp prose?(name), do: String.match?(name, ~r/^[A-Z]|^:|_|[?!]$/)

  @spec spellings(Vertex.t()) :: [String.t()]
  defp spellings(%{__struct__: struct, resource: resource} = vertex)
       when is_map_key(@fields, struct) do
    name =
      vertex |> Map.fetch!(Map.fetch!(@fields, struct)) |> Map.fetch!(:name) |> Atom.to_string()

    owners =
      Enum.uniq([
        resource |> Module.split() |> List.last(),
        Vertex.Name.in_app(resource),
        inspect(resource)
      ])

    [name, ":" <> name | Enum.map(owners, &(&1 <> "." <> name))]
  end

  defp spellings(vertex) do
    parts = vertex |> ModuleProvider.module() |> Module.split()

    in_app =
      case parts do
        [_app | [_, _ | _] = rest] -> [Enum.join(rest, ".")]
        _parts -> []
      end

    Enum.uniq([Enum.join(parts, ".") | in_app] ++ [List.last(parts)])
  end

  # The English plural of a resource's short name, by its last word:
  # Policies, Addresses, LineItems.
  @spec plurals(Vertex.t()) :: [String.t()]
  defp plurals(%Resource{resource: resource}) do
    name = resource |> Module.split() |> List.last()

    cond do
      String.match?(name, ~r/[^aeiou]y$/) -> [String.slice(name, 0..-2//1) <> "ies"]
      String.match?(name, ~r/(s|x|z|ch|sh)$/) -> [name <> "es"]
      true -> [name <> "s"]
    end
  end

  defp plurals(_vertex), do: []

  # The vertex a name fits, if it fits only one, or one ranks above the rest:
  # the nearest, and of those as near, the one it names rather than pluralises
  # (the Projects domain, not the Project resource's plural).
  @spec pick([{Vertex.t(), :name | :plural}], context()) :: Vertex.t() | nil
  defp pick([{vertex, _form}], _context), do: vertex

  defp pick(candidates, context) do
    candidates
    |> Enum.group_by(fn {vertex, form} -> {rank(vertex, context), form} end, &elem(&1, 0))
    |> Enum.min_by(&elem(&1, 0))
    |> case do
      {_rank, [vertex]} -> vertex
      _tied -> nil
    end
  end

  @spec rank(Vertex.t(), context()) :: 0 | 1 | 2 | 3
  defp rank(vertex, context) do
    home = home(vertex)

    cond do
      home != nil and home == context.resource -> 0
      home in context.related -> 1
      context.domain != nil and domain_of(vertex) == context.domain -> 2
      true -> 3
    end
  end

  # The resource a vertex is, or is a field of.
  @spec home(Vertex.t()) :: module() | nil
  defp home(%{resource: resource}), do: resource
  defp home(_vertex), do: nil

  @spec domain_of(Vertex.t()) :: module() | nil
  defp domain_of(%{__struct__: Domain, domain: domain}), do: domain
  defp domain_of(vertex), do: vertex |> home() |> domain()

  if Code.ensure_loaded?(Ash) do
    # Text about a resource or its field, or about a domain, resource or
    # module that is one, is read in its light.
    @spec context(Vertex.t() | nil) :: context()
    defp context(nil), do: about(nil)

    defp context(%{resource: resource}) when is_atom(resource) and resource != nil,
      do: about(resource)

    defp context(vertex), do: vertex |> ModuleProvider.module() |> about()

    @spec about(module() | nil) :: context()
    defp about(module) when is_atom(module) and module != nil do
      cond do
        Info.resource?(module) ->
          %{
            resource: module,
            related: module |> Info.relationships() |> Enum.map(& &1.destination),
            domain: Info.domain(module)
          }

        Spark.Dsl.is?(module, Ash.Domain) ->
          %{resource: nil, related: [], domain: module}

        true ->
          about(nil)
      end
    end

    defp about(_module), do: %{resource: nil, related: [], domain: nil}

    @spec domain(module() | nil) :: module() | nil
    defp domain(nil), do: nil

    defp domain(module) do
      if Info.resource?(module), do: Info.domain(module)
    end
  else
    @spec context(Vertex.t() | nil) :: context()
    defp context(_vertex), do: %{resource: nil, related: [], domain: nil}

    @spec domain(module() | nil) :: module() | nil
    defp domain(_module), do: nil
  end

  # Escapes values spliced into raw HTML.
  @spec escape(String.t()) :: String.t()
  defp escape(value), do: value |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
