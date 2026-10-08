defmodule Clarity.Report.Components do
  @moduledoc """
  The building blocks every report shares, so each reads the same way.

  A report's things to do (`Clarity.Report.Action`s) render with `actions/1`:
  `todo/1`s, most severe first, each naming what it affects with `chip/1`s
  and how to fix it. A `status/1` line counts them by severity, and a
  `count_badge/1` sums them up wherever they're listed. What there is to know
  goes in `section/1`s with `.report-table`s.

  Styled by the `.report-*` classes in `app.css`.
  """

  use Clarity.Web, :html

  alias Clarity.Perspective.Lens
  alias Clarity.Report.Action
  alias Clarity.Tooltip
  alias Phoenix.LiveView.Rendered

  attr :tally, :map, required: true, doc: "The to-dos counted by severity, `Action.tally/1`"
  attr :pending, :string, default: nil, doc: "What is still being checked, if anything"
  attr :patch, :string, default: nil, doc: "Where the to-dos are listed, if elsewhere"
  slot :meta, doc: "Small print below, e.g. how fresh the data is"

  @doc """
  The verdict, in a line: how many things there are to do, and how many at
  each severity.
  """
  @spec status(map()) :: Rendered.t()
  def status(assigns) do
    ~H"""
    <div class="report-status-block">
      <p class="report-status" data-tone={status_tone(@tally, @pending)}>
        <.icon_check :if={@tally.total == 0 and @pending == nil} class="size-5" />
        <.icon_spinner :if={@pending} class="size-5 animate-spin" />
        <.link
          :if={@patch && @pending == nil && @tally.total > 0}
          patch={@patch}
          class="report-status-link"
        >
          {status_text(@tally, nil)} →
        </.link>
        <span :if={!(@patch && @pending == nil && @tally.total > 0)}>
          {status_text(@tally, @pending)}
        </span>
        <span :if={@pending == nil and @tally.total > 0} class="report-tallies">
          <span
            :for={severity <- Action.severities()}
            :if={@tally[severity] > 0}
            class="report-tally"
            data-severity={severity}
          >
            {@tally[severity]} {severity}
          </span>
        </span>
      </p>
      <p :for={meta <- @meta} class="report-status-meta">{render_slot(meta)}</p>
    </div>
    """
  end

  @spec status_tone(Action.tally(), String.t() | nil) :: String.t()
  defp status_tone(_tally, pending) when is_binary(pending), do: "pending"
  defp status_tone(%{total: 0}, nil), do: "ok"
  defp status_tone(_tally, nil), do: "attention"

  @spec status_text(Action.tally(), String.t() | nil) :: String.t()
  defp status_text(_tally, pending) when is_binary(pending), do: pending
  defp status_text(%{total: 0}, nil), do: "Nothing to do"
  defp status_text(%{total: 1}, nil), do: "1 thing to do"
  defp status_text(%{total: total}, nil), do: "#{total} things to do"

  attr :tally, :map, default: nil, doc: "The to-dos counted, or nil while counting"
  attr :class, :any, default: nil

  @doc """
  The number of things to do, tinted by the most severe of them; nothing
  when there are none, or while they're being counted.
  """
  @spec count_badge(map()) :: Rendered.t()
  def count_badge(assigns) do
    ~H"""
    <span
      :if={@tally && @tally.total > 0}
      class={["count-badge", @class]}
      data-severity={@tally.worst}
      {Tooltip.attrs(tally_hint(@tally))}
    >
      {if @tally.total > 999, do: "999+", else: @tally.total}
    </span>
    """
  end

  @spec tally_hint(Action.tally()) :: String.t()
  defp tally_hint(tally) do
    Action.severities()
    |> Enum.filter(&(tally[&1] > 0))
    |> Enum.map_join(" · ", &"#{tally[&1]} #{&1}")
  end

  slot :inner_block, required: true

  @doc "The to-do items, in order."
  @spec todo_list(map()) :: Rendered.t()
  def todo_list(assigns) do
    ~H"""
    <ol class="report-todos">{render_slot(@inner_block)}</ol>
    """
  end

  attr :severity, :atom, required: true, values: [:high, :medium, :low]
  attr :title, :string, required: true, doc: "The problem, in a few words"
  attr :count, :integer, default: nil, doc: "How many things it affects"
  attr :hint, :string, default: nil, doc: "Why it matters, shown on hovering the title"
  attr :command, :string, default: nil, doc: "A command that fixes it, to copy"
  slot :inner_block, doc: "What it affects, usually as chips"
  slot :fix, doc: "How to fix it, in a line"

  @doc "One thing to do: how severe, what's wrong, what it affects and the fix."
  @spec todo(map()) :: Rendered.t()
  def todo(assigns) do
    ~H"""
    <li class="report-todo" data-severity={@severity}>
      <div class="report-todo-head">
        <span class="report-severity">{severity_label(@severity)}</span>
        <h3 class="report-todo-title" {Tooltip.attrs(@hint)}>
          {@title}<span :if={@count} class="report-todo-count">{@count}</span>
        </h3>
      </div>
      <div :if={@inner_block != []} class="report-todo-affects">{render_slot(@inner_block)}</div>
      <p :if={@fix != []} class="report-todo-fix">{render_slot(@fix)}</p>
      <.command :if={@command} text={@command} />
    </li>
    """
  end

  @spec severity_label(Action.severity()) :: String.t()
  defp severity_label(:high), do: "High"
  defp severity_label(:medium), do: "Medium"
  defp severity_label(:low), do: "Low"

  attr :text, :string, required: true

  @doc "A shell command, with a button to copy it."
  @spec command(map()) :: Rendered.t()
  def command(assigns) do
    ~H"""
    <div class="report-command">
      <code>{@text}</code>
      <button
        type="button"
        phx-click={JS.dispatch("clarity:copy-to-clipboard", detail: %{content: @text})}
        class="icon-button copy-button"
        aria-label="Copy command"
        {Tooltip.attrs("Copy command")}
      >
        <.icon_clipboard class="copy-idle" />
        <.icon_check class="copy-done" />
      </button>
    </div>
    """
  end

  attr :patch, :string, default: nil, doc: "The vertex page it opens, if any"
  attr :muted, :boolean, default: false, doc: "Whether it's of less concern, e.g. private"
  attr :hint, :string, default: nil
  slot :inner_block, required: true

  @doc "A name in a to-do or table: a resource, field, action or dependency."
  @spec chip(map()) :: Rendered.t()
  def chip(assigns) do
    ~H"""
    <.link
      :if={@patch}
      patch={@patch}
      class={["report-chip", @muted && "report-chip-muted"]}
      {Tooltip.attrs(@hint)}
    >
      {render_slot(@inner_block)}
    </.link>
    <span :if={!@patch} class={["report-chip", @muted && "report-chip-muted"]} {Tooltip.attrs(@hint)}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  slot :label, required: true, doc: "What the items belong to, e.g. a resource"
  slot :inner_block, required: true, doc: "The items, usually chips"

  @doc "A row in a to-do: what the items belong to, then the items."
  @spec group(map()) :: Rendered.t()
  def group(assigns) do
    ~H"""
    <div class="report-todo-group">
      <div class="report-todo-group-label">{render_slot(@label)}</div>
      <div class="report-todo-group-items">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  attr :count, :integer, required: true, doc: "How many more there are"
  slot :inner_block, required: true

  @doc "The rest of a long list of chips, behind \"+N more\"."
  @spec more(map()) :: Rendered.t()
  def more(assigns) do
    ~H"""
    <details class="report-more">
      <summary>+{@count} more</summary>
      <div class="report-more-items">{render_slot(@inner_block)}</div>
    </details>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :count, :integer, default: nil
  attr :open, :boolean, default: true
  slot :inner_block, required: true

  @doc """
  A section of what there is to know, open to scroll through; the reader can
  fold it away, and the browser keeps it as they leave it.
  """
  @spec section(map()) :: Rendered.t()
  def section(assigns) do
    ~H"""
    <details
      id={@id}
      class="report-section"
      open={@open}
      phx-mounted={JS.ignore_attributes(["open"])}
    >
      <summary>
        <.icon_chevron_right class="report-section-chevron" aria-hidden="true" />
        <span>{@title}</span>
        <span :if={@count} class="report-section-count">{@count}</span>
      </summary>
      <div class="report-section-body">{render_slot(@inner_block)}</div>
    </details>
    """
  end

  attr :actions, :list, required: true, doc: "`Clarity.Report.Action`s, most severe first"
  attr :prefix, :string, required: true
  attr :lens, :any, required: true
  attr :shown, :integer, default: 6, doc: "Items shown beside a label before \"+N more\""

  @doc "A report's things to do, from its `c:Clarity.Report.actions/2`."
  @spec actions(map()) :: Rendered.t()
  def actions(assigns) do
    ~H"""
    <.todo_list :if={@actions != []}>
      <.todo
        :for={action <- @actions}
        severity={action.severity}
        title={action.title}
        count={Action.count(action)}
        hint={action.hint}
        command={action.command}
      >
        <%= for group <- action.groups do %>
          <%= if action.layout == :lines do %>
            <div :for={item <- group.items} class="report-todo-line">
              <.item item={item} prefix={@prefix} lens={@lens} />
              <span :if={item[:note]} class="report-todo-note">{item.note}</span>
              <span :for={detail <- item[:details] || []} class="report-todo-detail">{detail}</span>
            </div>
          <% else %>
            <.group :if={group[:label]}>
              <:label>
                <.link
                  :if={group[:id]}
                  patch={path(@prefix, @lens, group.id)}
                  class="report-link"
                >
                  {group.label}
                </.link>
                <span :if={!group[:id]}>{group.label}</span>
              </:label>
              <.item
                :for={item <- Enum.take(group.items, @shown)}
                item={item}
                prefix={@prefix}
                lens={@lens}
              />
              <.more :if={length(group.items) > @shown} count={length(group.items) - @shown}>
                <.item
                  :for={item <- Enum.drop(group.items, @shown)}
                  item={item}
                  prefix={@prefix}
                  lens={@lens}
                />
              </.more>
            </.group>
            <.item
              :for={item <- if(group[:label], do: [], else: group.items)}
              item={item}
              prefix={@prefix}
              lens={@lens}
            />
          <% end %>
        <% end %>
        <:fix :if={action.fix}>{fix_text(action.fix)}</:fix>
      </.todo>
    </.todo_list>
    """
  end

  attr :item, :map, required: true
  attr :prefix, :string, required: true
  attr :lens, :any, required: true

  @spec item(map()) :: Rendered.t()
  defp item(assigns) do
    ~H"""
    <.chip
      patch={@item[:id] && path(@prefix, @lens, @item.id)}
      muted={@item[:muted?] || false}
      hint={@item[:hint]}
    >
      {@item.text}
    </.chip>
    """
  end

  # A fix's text, with the parts between backticks as code. Built as one
  # string, so no whitespace creeps in between the parts.
  # sobelow_skip ["XSS.Raw"]
  @spec fix_text(String.t()) :: Phoenix.HTML.safe()
  defp fix_text(text) do
    text
    |> String.split("`")
    |> Enum.with_index()
    |> Enum.map(fn
      {part, index} when rem(index, 2) == 1 -> ["<code>", escape(part), "</code>"]
      {part, _index} -> escape(part)
    end)
    |> raw()
  end

  @spec escape(String.t()) :: iodata()
  defp escape(text), do: text |> html_escape() |> safe_to_string()

  @doc "A vertex's page in a lens."
  @spec path(String.t(), Lens.t(), String.t()) :: String.t()
  def path(prefix, %Lens{id: lens_id}, vertex_id), do: Path.join([prefix, lens_id, vertex_id])

  attr :name, :string, required: true

  @doc """
  A dotted name, such as `Demo.Accounts.User.email`, that may break after a
  dot when it doesn't fit, rather than push what's beside it aside. Give its
  column a minimum width, or a table squeezed for room breaks it at every dot.
  """
  @spec dotted(map()) :: Rendered.t()
  def dotted(assigns) do
    assigns = assign(assigns, :parts, String.split(assigns.name, "."))

    ~H"""
    <span phx-no-format><%= for {part, index} <- Enum.with_index(@parts) do %><%= if index > 0 do %>.<wbr /><% end %>{part}<% end %></span>
    """
  end

  attr :graph, :any, required: true, doc: "The graph that holds the vertex, for its hover hint"
  attr :prefix, :string, required: true
  attr :lens, :any, required: true
  attr :id, :string, required: true, doc: "The vertex's id"
  slot :inner_block, required: true

  @doc "A link to a vertex's page, by its id, with the vertex's hover hint."
  @spec vertex_link(map()) :: Rendered.t()
  def vertex_link(assigns) do
    assigns = assign(assigns, :hint, hint(assigns.graph, assigns.id))

    ~H"""
    <.link patch={path(@prefix, @lens, @id)} class="report-link" {@hint}>{render_slot(@inner_block)}</.link>
    """
  end

  @spec hint(Clarity.Graph.t() | nil, String.t()) :: keyword(String.t())
  defp hint(nil, _id), do: []

  defp hint(graph, id) do
    case Clarity.Graph.get_vertex(graph, id) do
      nil -> []
      vertex -> Tooltip.attrs(vertex)
    end
  end
end
