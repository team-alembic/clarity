defmodule Clarity.Autolink do
  @moduledoc """
  Links the names of vertices where rendered text mentions them, so a
  description such as "A single utterance inside a Conversation, from a User"
  links Conversation and User to their pages.

  A vertex is named by its module (`Demo.Helpdesk.Conversation`), by its name
  within the application (`Helpdesk.Conversation`) and, for resources and
  Reactors, by its short name (`Conversation`). When a short name fits more
  than one vertex, the text's own vertex settles it: a resource it has a
  relationship to first, then one in its domain; if that doesn't, the name
  isn't linked. Only whole words link, each vertex only at its first mention,
  and never the vertex the text describes, nor text in a heading, a link or a
  code block.
  """

  alias Ash.Resource.Info
  alias Clarity.Graph
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Domain
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.ModuleProvider

  @typedoc "Names that link, each to the vertex it names."
  @type names() :: %{String.t() => Vertex.t()}

  # The resources the text's vertex relates to, and its domain.
  @typep context() :: %{related: [module()], domain: module() | nil}

  @linkable [Resource, Domain, Vertex.Reactor]
  # Domains' short names ("Billing") are too common a word to link.
  @short_named [Resource, Vertex.Reactor]

  @doc """
  Returns the names to link in text about `vertex` (or about nothing in
  particular, with `nil`), from the vertices in `graph`.
  """
  @spec names(Graph.t(), Vertex.t() | nil) :: names()
  def names(graph, vertex) do
    context = context(vertex)

    graph
    |> Graph.vertices({:in, :vertex_type, @linkable})
    |> Enum.reject(&(&1 == vertex))
    |> Enum.flat_map(fn named -> Enum.map(spellings(named), &{&1, named}) end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.flat_map(fn {name, vertices} ->
      case pick(Enum.uniq(vertices), context) do
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
    alternatives =
      names
      |> Map.keys()
      |> Enum.sort_by(&String.length/1, :desc)
      |> Enum.map_join("|", &Regex.escape/1)

    # A whole name: not part of a longer word or module name.
    regex = Regex.compile!("(?<![\\w.])(?:#{alternatives})(?![\\w]|\\.\\w)", "u")

    {document, _linked} = walk(document, %{names: names, regex: regex, path: path}, MapSet.new())
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

  @spec walk(MDEx.Document.md_node(), map(), MapSet.t()) :: {MDEx.Document.md_node(), MapSet.t()}
  defp walk(%MDEx.Link{} = node, _context, linked), do: {node, linked}
  defp walk(%MDEx.Heading{} = node, _context, linked), do: {node, linked}

  defp walk(%{nodes: nodes} = node, context, linked) when is_list(nodes) do
    {nodes, linked} = Enum.flat_map_reduce(nodes, linked, &child(&1, context, &2))
    {%{node | nodes: nodes}, linked}
  end

  defp walk(node, _context, linked), do: {node, linked}

  @spec child(MDEx.Document.md_node(), map(), MapSet.t()) ::
          {[MDEx.Document.md_node()], MapSet.t()}
  defp child(%MDEx.Text{literal: text}, context, linked) do
    context.regex
    |> Regex.split(text, include_captures: true, trim: true)
    |> Enum.flat_map_reduce(linked, &mention(&1, [%MDEx.Text{literal: &1}], context, &2))
  end

  defp child(%MDEx.Code{literal: literal} = code, context, linked),
    do: mention(literal, [code], context, linked)

  defp child(node, context, linked) do
    {node, linked} = walk(node, context, linked)
    {[node], linked}
  end

  # Links `nodes` if `text` names a vertex not yet linked, or leaves them be.
  @spec mention(String.t(), [MDEx.Document.md_node()], map(), MapSet.t()) ::
          {[MDEx.Document.md_node()], MapSet.t()}
  defp mention(text, nodes, context, linked) do
    case Map.fetch(context.names, text) do
      {:ok, vertex} ->
        if MapSet.member?(linked, vertex),
          do: {nodes, linked},
          else: {patch_link(context.path.(vertex), nodes), MapSet.put(linked, vertex)}

      :error ->
        {nodes, linked}
    end
  end

  @spec spellings(Vertex.t()) :: [String.t()]
  defp spellings(vertex) do
    parts = vertex |> ModuleProvider.module() |> Module.split()

    in_app =
      case parts do
        [_app | [_, _ | _] = rest] -> [Enum.join(rest, ".")]
        _parts -> []
      end

    short = if vertex.__struct__ in @short_named, do: [List.last(parts)], else: []

    Enum.uniq([Enum.join(parts, ".") | in_app] ++ short)
  end

  # The vertex a name fits, if it fits only one, or one ranks above the rest.
  @spec pick([Vertex.t()], context()) :: Vertex.t() | nil
  defp pick([vertex], _context), do: vertex

  defp pick(vertices, context) do
    case vertices |> Enum.group_by(&rank(&1, context)) |> Enum.min_by(&elem(&1, 0)) do
      {_rank, [vertex]} -> vertex
      _tied -> nil
    end
  end

  @spec rank(Vertex.t(), context()) :: 0 | 1 | 2
  defp rank(vertex, context) do
    module = ModuleProvider.module(vertex)

    cond do
      module in context.related -> 0
      context.domain != nil and domain(module) == context.domain -> 1
      true -> 2
    end
  end

  if Code.ensure_loaded?(Ash) do
    @spec context(Vertex.t() | nil) :: context()
    defp context(%{__struct__: Domain, domain: domain}), do: %{related: [], domain: domain}

    defp context(%{resource: resource}) when is_atom(resource) and resource != nil do
      if Info.resource?(resource) do
        %{
          related: resource |> Info.relationships() |> Enum.map(& &1.destination),
          domain: Info.domain(resource)
        }
      else
        context(nil)
      end
    end

    defp context(_vertex), do: %{related: [], domain: nil}

    @spec domain(module()) :: module() | nil
    defp domain(module) do
      if Info.resource?(module), do: Info.domain(module)
    end
  else
    @spec context(Vertex.t() | nil) :: context()
    defp context(_vertex), do: %{related: [], domain: nil}

    @spec domain(module()) :: module() | nil
    defp domain(_module), do: nil
  end

  # Escapes values spliced into raw HTML.
  @spec escape(String.t()) :: String.t()
  defp escape(value), do: value |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
