defmodule Clarity.Report.Action do
  @moduledoc """
  One kind of thing to do that a report finds, e.g. "Resources with no
  policies", with the items it applies to. Each item is one to-do: a resource
  to add policies to, a field to document, a dependency to update.

  Items sit in groups: a group's `label` says what its items belong to (a
  resource, a domain), or is `nil` for items that stand alone. With the
  `:lines` layout each item takes a line of its own, with its `note` and
  `details`; with `:chips` (the default) items wrap beside their label.

  `fix` says how to fix it in a line; text between backticks is code.
  """

  @typedoc "How soon it wants doing."
  @type severity() :: :high | :medium | :low

  @typedoc "One to-do: what it applies to, linked to its vertex when it has one."
  @type item() :: %{
          required(:text) => String.t(),
          optional(:id) => String.t() | nil,
          optional(:muted?) => boolean(),
          optional(:hint) => String.t() | nil,
          optional(:note) => String.t() | nil,
          optional(:details) => [String.t()]
        }

  @type group() :: %{
          required(:items) => [item()],
          optional(:label) => String.t() | nil,
          optional(:id) => String.t() | nil
        }

  @type t() :: %__MODULE__{
          severity: severity(),
          title: String.t(),
          hint: String.t() | nil,
          fix: String.t() | nil,
          command: String.t() | nil,
          layout: :chips | :lines,
          groups: [group()]
        }

  @enforce_keys [:severity, :title, :groups]
  defstruct [:severity, :title, :hint, :fix, :command, layout: :chips, groups: []]

  @typedoc "How many to-dos there are at each severity, and the worst."
  @type tally() :: %{
          high: non_neg_integer(),
          medium: non_neg_integer(),
          low: non_neg_integer(),
          total: non_neg_integer(),
          worst: severity() | nil
        }

  @severities [:high, :medium, :low]

  @doc "The severities, most severe first."
  @spec severities() :: [severity()]
  def severities, do: @severities

  @doc "How many to-dos the action holds: one per item."
  @spec count(t()) :: non_neg_integer()
  def count(%__MODULE__{groups: groups}), do: Enum.sum_by(groups, &length(&1.items))

  @doc """
  Counts the to-dos in `actions` at each severity.

      iex> alias Clarity.Report.Action
      ...>
      ...> Action.tally([
      ...>   %Action{severity: :low, title: "a", groups: [%{items: [%{text: "x"}, %{text: "y"}]}]},
      ...>   %Action{severity: :medium, title: "b", groups: [%{items: [%{text: "z"}]}]}
      ...> ])
      %{high: 0, medium: 1, low: 2, total: 3, worst: :medium}
  """
  @spec tally([t()]) :: tally()
  def tally(actions) do
    counts = Map.new(@severities, fn severity -> {severity, 0} end)

    counts =
      Enum.reduce(actions, counts, fn action, counts ->
        Map.update!(counts, action.severity, &(&1 + count(action)))
      end)

    Map.merge(counts, %{
      total: counts |> Map.values() |> Enum.sum(),
      worst: Enum.find(@severities, &(counts[&1] > 0))
    })
  end

  @doc """
  Adds tallies together, e.g. a category's reports, or every report.

      iex> alias Clarity.Report.Action
      ...>
      ...> Action.sum([
      ...>   %{high: 0, medium: 1, low: 2, total: 3, worst: :medium},
      ...>   %{high: 1, medium: 0, low: 0, total: 1, worst: :high}
      ...> ])
      %{high: 1, medium: 1, low: 2, total: 4, worst: :high}
  """
  @spec sum([tally()]) :: tally()
  def sum(tallies) do
    counts =
      Map.new(@severities, fn severity -> {severity, Enum.sum_by(tallies, & &1[severity])} end)

    Map.merge(counts, %{
      total: counts |> Map.values() |> Enum.sum(),
      worst: Enum.find(@severities, &(counts[&1] > 0))
    })
  end

  @doc "A tally with nothing to do."
  @spec empty_tally() :: tally()
  def empty_tally, do: sum([])
end
