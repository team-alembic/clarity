defmodule Clarity.Vertex.Name do
  @moduledoc """
  Display-name helpers for Clarity vertices.

  `Clarity.Vertex.name/1` always returns the canonical, fully-qualified
  label for a vertex (e.g. `"Demo.Accounts.Organization"`). The dashboard
  optionally renders the short, last-segment-only form (`"Organization"`)
  for users who prefer a denser sidebar / breadcrumb display.

  This module owns that switch. `display/2` selects between the qualified
  and short forms based on the current `t:style/0`.

  Vertex types whose `name/1` is already short (an atom action name, a
  section path, an OTP application name, etc.) are unaffected — those
  vertices have no `Clarity.Vertex.ModuleProvider` implementation, so
  `display/2` falls through to `Clarity.Vertex.name/1`.
  """

  alias Clarity.Vertex
  alias Clarity.Vertex.ModuleProvider

  @typedoc "Display preference for module-named vertices."
  @type style() :: :qualified | :short

  @doc """
  Render `vertex` using the requested `style`.

  Returns `Clarity.Vertex.name/1` verbatim for the `:qualified` style and
  for any vertex without a `Clarity.Vertex.ModuleProvider` implementation.
  For `:short` on a module-named vertex, returns the last segment of the
  module name (e.g. `Demo.Accounts.Organization -> "Organization"`).
  """
  @spec display(Vertex.t(), style()) :: String.t()
  def display(vertex, :short) do
    case ModuleProvider.module(vertex) do
      nil -> Vertex.name(vertex)
      module when is_atom(module) -> short_module_name(module)
    end
  end

  def display(vertex, _style), do: Vertex.name(vertex)

  @doc """
  Last segment of a module name. Falls back to `inspect/1` for atoms that
  cannot be split (e.g. erlang-style atoms).
  """
  @spec short_module_name(module()) :: String.t()
  def short_module_name(module) when is_atom(module) do
    module |> Module.split() |> List.last()
  rescue
    ArgumentError -> inspect(module)
  end
end
