defmodule Clarity.Report.Components do
  @moduledoc """
  The building blocks every report shares, so each reads the same way: a
  `status/1` line saying how much there is to do, a list of `todo/1` items
  (most severe first), each naming what it affects with `chip/1`s and how to
  fix it, and the reference data below in closed `section/1`s.

  Styled by the `.report-*` classes in `app.css`.
  """

  use Clarity.Web, :html

  alias Clarity.Perspective.Lens
  alias Clarity.Tooltip
  alias Phoenix.LiveView.Rendered

  @typedoc "How soon a to-do wants doing."
  @type severity() :: :high | :medium | :low

  attr :count, :integer, required: true, doc: "How many to-dos the report lists"
  attr :pending, :string, default: nil, doc: "What is still being checked, if anything"
  slot :meta, doc: "Small print below, e.g. how fresh the data is"

  @doc "The report's verdict, in a line: how many things there are to do."
  @spec status(map()) :: Rendered.t()
  def status(assigns) do
    ~H"""
    <div class="report-status-block">
      <p class="report-status" data-tone={status_tone(@count, @pending)}>
        <.icon_check :if={@count == 0 and @pending == nil} class="size-5" />
        <.icon_spinner :if={@pending} class="size-5 animate-spin" />
        {status_text(@count, @pending)}
      </p>
      <p :for={meta <- @meta} class="report-status-meta">{render_slot(meta)}</p>
    </div>
    """
  end

  @spec status_tone(non_neg_integer(), String.t() | nil) :: String.t()
  defp status_tone(_count, pending) when is_binary(pending), do: "pending"
  defp status_tone(0, nil), do: "ok"
  defp status_tone(_count, nil), do: "attention"

  @spec status_text(non_neg_integer(), String.t() | nil) :: String.t()
  defp status_text(_count, pending) when is_binary(pending), do: pending
  defp status_text(0, nil), do: "Nothing to do"
  defp status_text(1, nil), do: "1 thing to do"
  defp status_text(count, nil), do: "#{count} things to do"

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

  @spec severity_label(severity()) :: String.t()
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

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :count, :integer, default: nil
  attr :open, :boolean, default: false
  slot :inner_block, required: true

  @doc """
  Reference data below the to-dos, closed until wanted. The browser keeps it
  as the reader leaves it.
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

  @doc "A vertex's page in a lens."
  @spec path(String.t(), Lens.t(), String.t()) :: String.t()
  def path(prefix, %Lens{id: lens_id}, vertex_id), do: Path.join([prefix, lens_id, vertex_id])
end
