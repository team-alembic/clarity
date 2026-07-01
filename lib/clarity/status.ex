defmodule Clarity.Status do
  @moduledoc """
  A status flag attached to a vertex by a `Clarity.Status.Provider`.

  Statuses surface in the navigation tree as info/warning/error indicators and
  roll up so that a collapsed subtree reflects the most severe status buried
  inside it.

  The `class` is a semantic domain (e.g. `:security`, `:hygiene`) that lenses
  filter on to decide which statuses they surface — decoupled from the producing
  module, so any provider can contribute to a class. The `source` is the
  producing module, kept for provenance and tooltips, not for filtering.
  """

  @typedoc "Severity, ordered least to most severe."
  @type severity() :: :info | :warning | :error

  @type t() :: %__MODULE__{
          severity: severity(),
          class: atom(),
          message: String.t(),
          source: module()
        }

  @enforce_keys [:severity, :class, :message, :source]
  defstruct [:severity, :class, :message, :source]

  @severities [:info, :warning, :error]

  @doc """
  All severities, ordered least to most severe.

  ## Examples

      iex> Clarity.Status.severities()
      [:info, :warning, :error]
  """
  @spec severities() :: [severity()]
  def severities, do: @severities

  @doc """
  The rank of a severity, for comparison (higher is more severe).

  ## Examples

      iex> Clarity.Status.rank(:info) < Clarity.Status.rank(:error)
      true
  """
  @spec rank(severity()) :: non_neg_integer()
  def rank(:info), do: 0
  def rank(:warning), do: 1
  def rank(:error), do: 2

  @doc """
  Returns the more severe of two severities.

  ## Examples

      iex> Clarity.Status.max_severity(:info, :warning)
      :warning

      iex> Clarity.Status.max_severity(:error, :warning)
      :error
  """
  @spec max_severity(severity(), severity()) :: severity()
  def max_severity(left, right) when is_atom(left) and is_atom(right) do
    if rank(left) >= rank(right), do: left, else: right
  end
end
