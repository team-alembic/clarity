defmodule Clarity.Components.OverviewComponents do
  @moduledoc """
  The building blocks of overview tabs, in the tones and icons of hover hints
  and the navigation tree (see `Clarity.Tooltip`).

  An overview leads with what matters: a `hero/1` with the vertex's type, its
  essence in a sentence and its description, then `facts/1` and `stats/1`
  that jump to the `section/1`s below. Rows name other vertices with
  `vertex_link/1`, which carries the vertex's icon and hover hint, and call
  out what's notable with `flag/1` rather than columns of true and false.
  """

  use Phoenix.Component

  import Clarity.Components.MarkdownComponent

  alias Clarity.Autolink
  alias Clarity.Perspective.Lens
  alias Clarity.Tooltip
  alias Clarity.Vertex
  alias Phoenix.LiveView.Rendered

  @typedoc """
  What an overview's links need: where they go, and the names its text links
  (from `Clarity.Autolink`), settled once for the vertex the overview is about.
  """
  @type links() :: %{
          prefix: String.t(),
          lens: Lens.t(),
          graph: Clarity.Graph.t() | nil,
          index: Autolink.index() | nil,
          vertex: Vertex.t(),
          names: Autolink.names() | nil,
          linking: Autolink.options()
        }

  @doc """
  Gathers what an overview's links need from a content component's assigns:
  `prefix`, `lens`, `vertex`, and `graph` and `linking` when given.
  """
  @spec links(map()) :: links()
  def links(assigns) do
    graph = Map.get(assigns, :graph)
    linking = Map.get(assigns, :linking, [])
    index = if graph, do: Autolink.index(graph, linking)

    %{
      prefix: assigns.prefix,
      lens: assigns.lens,
      graph: graph,
      index: index,
      vertex: assigns.vertex,
      names: index && Autolink.names_in(index, assigns.vertex),
      linking: linking
    }
  end

  @doc """
  Returns `links` for text about another `vertex`, such as a section of the
  overview about one of the vertex's parts, so its names settle by nearness
  to that instead.
  """
  @spec links_about(links(), Vertex.t()) :: links()
  def links_about(%{index: nil} = links, vertex), do: %{links | vertex: vertex}

  def links_about(links, vertex),
    do: %{links | vertex: vertex, names: Autolink.names_in(links.index, vertex)}

  @doc """
  Returns the graph's own copy of `vertex`, which may know more than one
  built from scratch (an application's description and version), or `nil`
  when the graph doesn't hold it or there's no graph.
  """
  @spec in_graph(links(), Vertex.t()) :: Vertex.t() | nil
  def in_graph(%{graph: nil}, _vertex), do: nil
  def in_graph(%{graph: graph}, vertex), do: Clarity.Graph.get_vertex(graph, Vertex.id(vertex))

  @doc "Returns the path to `vertex` in the overview's lens."
  @spec path(links(), Vertex.t()) :: String.t()
  def path(links, vertex), do: Path.join([links.prefix, links.lens.id, Vertex.id(vertex)])

  @doc """
  Renders a vertex type's icon in its tone, as the tree does, or large on a
  tinted tile.
  """
  attr :vertex, :any, default: nil, doc: "The vertex whose type's icon to show"
  attr :icon, :string, default: "generic", doc: "The icon, without a vertex"
  attr :tone, :string, default: "neutral", doc: "The icon's tone, without a vertex"
  attr :size, :atom, default: :sm, values: [:sm, :lg]
  attr :class, :any, default: nil

  @spec type_icon(map()) :: Rendered.t()
  def type_icon(%{vertex: vertex} = assigns) when vertex != nil do
    assigns |> assign(Tooltip.type_icon(vertex)) |> assign(:vertex, nil) |> type_icon()
  end

  def type_icon(assigns) do
    ~H"""
    <span
      class={["ov-icon", @size == :lg && "ov-icon-lg", @class]}
      data-tone={@tone}
      aria-hidden="true"
    >
      <svg><use href={"#clarity-icon-#{@icon}"} /></svg>
    </span>
    """
  end

  @doc """
  Renders the top of an overview, under the page's header with the vertex's
  icon, name and type: what kind of the type it is when that says more
  (`Create action` for an `Action`), flags beside it, its essence in a
  sentence, and below them its description.
  """
  attr :vertex, :any, required: true

  attr :kind, :string,
    required: true,
    doc: ~s(What the vertex is, on its type pill: "Create action")

  slot :badge, doc: "Flags beside the type pill"
  slot :headline, doc: "The vertex's essence, in a sentence"
  slot :inner_block, doc: "The description, and whatever else leads the overview"

  @spec hero(map()) :: Rendered.t()
  def hero(assigns) do
    assigns =
      assign(assigns,
        type: Tooltip.type_icon(assigns.vertex),
        specific?: assigns.kind != Tooltip.type_name(assigns.vertex)
      )

    ~H"""
    <header class="ov-hero">
      <div class="min-w-0 flex-1">
        <div :if={@specific? or @badge != []} class="flex flex-wrap items-center gap-1.5">
          <span :if={@specific?} class="ov-pill" data-tone={@type.tone}>{@kind}</span>
          {render_slot(@badge)}
        </div>
        <p :if={@headline != []} class="ov-headline">{render_slot(@headline)}</p>
        <div :if={@inner_block != []} class="ov-hero-body">{render_slot(@inner_block)}</div>
      </div>
    </header>
    """
  end

  @doc """
  Renders a description as markdown, linking the names it mentions, or
  nothing when there is none.
  """
  attr :links, :map, required: true
  attr :text, :any, required: true
  attr :lead, :boolean, default: false, doc: "Whether it leads the overview, a little larger"
  attr :small, :boolean, default: false, doc: "Whether it's a row's aside, a little smaller"
  attr :sentence, :boolean, default: false, doc: "Whether to show only its first sentence"
  attr :class, :string, default: ""

  @spec description(map()) :: Rendered.t()
  def description(assigns) do
    assigns =
      if assigns.sentence, do: assign(assigns, :text, first_sentence(assigns.text)), else: assigns

    ~H"""
    <.markdown
      :if={present?(@text)}
      content={@text}
      prefix={@links.prefix}
      lens={@links.lens}
      graph={@links.graph}
      vertex={@links.vertex}
      names={@links.names}
      linking={@links.linking}
      class={"ov-prose #{if @lead, do: "ov-lead"} #{if @small, do: "ov-small"} #{@class}"}
    />
    """
  end

  @doc """
  Renders a link to a vertex with its icon, whose hover hint is the
  vertex's own.
  """
  attr :links, :map, required: true
  attr :vertex, :any, required: true
  attr :label, :string, default: nil, doc: "The label, if not the vertex's short name"
  attr :code, :boolean, default: false, doc: "Whether the label is code, such as a field's name"
  attr :icon, :boolean, default: true
  attr :class, :any, default: nil

  @spec vertex_link(map()) :: Rendered.t()
  def vertex_link(assigns) do
    ~H"""
    <.link
      patch={path(@links, @vertex)}
      class={["ov-link", @code && "ov-code", @class]}
      {Tooltip.attrs(@vertex)}
    >
      <.type_icon :if={@icon} vertex={@vertex} />{@label || label(@vertex)}
    </.link>
    """
  end

  @doc """
  Renders label and value facts as a compact grid of cells.
  """
  attr :class, :any, default: nil

  slot :fact, required: true do
    attr :label, :string, required: true
  end

  @spec facts(map()) :: Rendered.t()
  def facts(assigns) do
    ~H"""
    <dl :if={@fact != []} class={["ov-facts", @class]}>
      <div :for={fact <- @fact} class="ov-fact">
        <dt>{fact.label}</dt>
        <dd>{render_slot(fact)}</dd>
      </div>
    </dl>
    """
  end

  @doc """
  Renders counts that jump to the sections below, in their types' icons.
  """
  slot :stat do
    attr :label, :string, required: true
    attr :count, :integer, required: true
    attr :href, :string
    attr :icon, :string
    attr :tone, :string
  end

  @spec stats(map()) :: Rendered.t()
  def stats(assigns) do
    ~H"""
    <nav :if={@stat != []} class="ov-stats" aria-label="Contents">
      <a :for={stat <- @stat} href={stat[:href]} class="ov-stat">
        <.type_icon icon={stat[:icon] || "generic"} tone={stat[:tone] || "neutral"} />
        <span class="ov-stat-count">{stat.count}</span>
        {stat.label}
      </a>
    </nav>
    """
  end

  @doc """
  Renders a titled section of an overview, with its type's icon and a count.
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :icon, :string, default: nil
  attr :tone, :string, default: "neutral"
  attr :count, :integer, default: nil
  slot :aside, doc: "Anything at the end of the title row"
  slot :inner_block, required: true

  @spec section(map()) :: Rendered.t()
  def section(assigns) do
    ~H"""
    <section id={@id} class="ov-section">
      <h2 class="ov-section-title">
        <.type_icon :if={@icon} icon={@icon} tone={@tone} />
        {@title}
        <span :if={@count} class="ov-count">{@count}</span>
        <span :if={@aside != []} class="ov-section-aside">{render_slot(@aside)}</span>
      </h2>
      {render_slot(@inner_block)}
    </section>
    """
  end

  @doc """
  Renders rows as a compact table.
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :class, :any, default: nil

  slot :col, required: true do
    attr :label, :string
    attr :class, :string
  end

  @spec overview_table(map()) :: Rendered.t()
  def overview_table(assigns) do
    ~H"""
    <div class="ov-table-wrap">
      <table id={@id} class={["ov-table", @class]}>
        <thead>
          <tr>
            <th :for={col <- @col} class={col[:class]}>{col[:label]}</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={row <- @rows}>
            <td :for={col <- @col} class={col[:class]}>{render_slot(col, row)}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a short flag calling something out, such as `primary key` or
  `sensitive`, coloured for its kind and explained on hover.

  A flag with one of the badges `Clarity.Tooltip.badge/1` knows, as its
  `text`, takes that badge's colour and explanation, so it reads the same
  as on hover hints; `kind` and `hint` override them.
  """
  attr :text, :string, default: nil, doc: "The flag's text, if a badge Clarity knows"
  attr :kind, :atom, default: nil, values: [nil, :plain, :key, :good, :warn, :danger, :muted]
  attr :hint, :string, default: nil
  slot :inner_block

  @spec flag(map()) :: Rendered.t()
  def flag(assigns) do
    badge = if assigns.text, do: Tooltip.badge(assigns.text), else: %{kind: :plain, hint: nil}
    assigns = assign(assigns, kind: assigns.kind || badge.kind, hint: assigns.hint || badge.hint)

    ~H"""
    <span class="ov-flag" data-kind={@kind} {Tooltip.attrs(@hint)}>{@text}{render_slot(@inner_block)}</span>
    """
  end

  @doc """
  Renders a pill that names another vertex, such as a resource's data
  layer, in that vertex's icon and tone, linking to it (or to `to`) with
  its hover hint (or `hint`).
  """
  attr :links, :map, required: true
  attr :vertex, :any, required: true
  attr :label, :string, required: true
  attr :to, :string, default: nil, doc: "Where it links, if not to the vertex's page"
  attr :hint, :string, default: nil, doc: "Its hover hint, if not the vertex's"
  attr :icon, :string, default: nil, doc: "Its icon, if not the vertex type's"
  attr :tone, :string, default: nil, doc: "Its tone, if not the vertex type's"

  @spec vertex_pill(map()) :: Rendered.t()
  def vertex_pill(assigns) do
    type = Tooltip.type_icon(assigns.vertex)

    assigns =
      assign(assigns,
        icon: assigns.icon || type.icon,
        tone: assigns.tone || type.tone,
        to: assigns.to || path(assigns.links, assigns.vertex),
        hint_attrs: Tooltip.attrs(assigns.hint || assigns.vertex)
      )

    ~H"""
    <.link patch={@to} class="ov-pill ov-pill-link" data-tone={@tone} {@hint_attrs}>
      <.type_icon icon={@icon} tone={@tone} />{@label}
    </.link>
    """
  end

  @doc """
  Renders how much of a whole something is, as a bar.
  """
  attr :value, :integer, required: true
  attr :total, :integer, required: true
  attr :label, :string, default: nil, doc: "What the bar measures, for screen readers"

  @spec meter(map()) :: Rendered.t()
  def meter(assigns) do
    assigns =
      assign(
        assigns,
        :percent,
        if(assigns.total > 0, do: round(assigns.value * 100 / assigns.total), else: 0)
      )

    ~H"""
    <div
      class="ov-meter"
      role="meter"
      aria-valuemin="0"
      aria-valuemax={@total}
      aria-valuenow={@value}
      aria-label={@label}
    >
      <span class="ov-meter-fill" style={"width: #{@percent}%"}></span>
    </div>
    """
  end

  @doc """
  Renders a callout: a finding worth reading first, coloured for its kind.
  """
  attr :kind, :atom, default: :warn, values: [:warn, :danger]
  slot :inner_block, required: true

  @spec callout(map()) :: Rendered.t()
  def callout(assigns) do
    ~H"""
    <div class="ov-callout" data-kind={@kind} role="note">
      <.type_icon icon="advisory" tone="warning" />
      <div class="min-w-0">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  @doc """
  Renders names as code, a few at a time, with a count of the rest.
  """
  attr :names, :list, required: true
  attr :max, :integer, default: 12

  @spec code_list(map()) :: Rendered.t()
  def code_list(assigns) do
    {shown, hidden} = Enum.split(assigns.names, assigns.max)
    assigns = assign(assigns, shown: shown, hidden: length(hidden))

    ~H"""
    <span class="ov-code-list">
      <%= for name <- @shown do %>
        <code>{name}</code>{" "}
      <% end %>
      <span :if={@hidden > 0} class="ov-muted">+{@hidden} more</span>
    </span>
    """
  end

  @doc """
  Returns the first sentence of a text's first paragraph, or the paragraph
  when it has no sentence's end.

  ## Examples

      iex> Clarity.Components.OverviewComponents.first_sentence("A Ticket. Carries `id`, e.g. 1.")
      "A Ticket."

      iex> Clarity.Components.OverviewComponents.first_sentence("Tenant root\\n\\nMore.")
      "Tenant root"

  """
  @spec first_sentence(String.t() | nil) :: String.t() | nil
  def first_sentence(nil), do: nil

  def first_sentence(text) do
    [paragraph | _rest] = text |> String.trim() |> String.split(~r/\n\s*\n/, parts: 2)

    case Regex.run(~r/^.+?[.!?](?=\s+[A-Z(`*\[]|\s*$)/s, paragraph) do
      [sentence] -> sentence
      nil -> paragraph
    end
  end

  @spec label(Vertex.t()) :: String.t()
  defp label(vertex), do: Vertex.Name.display(vertex, :short)

  @spec present?(term()) :: boolean()
  defp present?(text) when is_binary(text), do: String.trim(text) != ""
  defp present?(text), do: text not in [nil, []]
end
