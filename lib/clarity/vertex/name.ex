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

  Returns `Clarity.Vertex.name/1` verbatim for the `:qualified` style.

  For `:short`, the last segment of the vertex's module name is used —
  but only when the vertex's canonical name actually IS the qualified
  module name (e.g. `Demo.Accounts.Organization`). For vertices whose
  canonical name is already short and unrelated to the implementation
  module (e.g. an action whose `run` is a module, but whose name is the
  atom `:onboard`), `Vertex.name/1` is returned verbatim — the short
  form is not derived from the underlying module.
  """
  @spec display(Vertex.t(), style()) :: String.t()
  def display(vertex, :short) do
    canonical = Vertex.name(vertex)

    case ModuleProvider.module(vertex) do
      module when is_atom(module) and not is_nil(module) ->
        if canonical == inspect(module),
          do: short_module_name(module),
          else: canonical

      _ ->
        canonical
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
