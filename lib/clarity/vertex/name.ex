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
    case module_segments(vertex) do
      nil -> Vertex.name(vertex)
      segments -> List.last(segments)
    end
  end

  def display(vertex, _style), do: Vertex.name(vertex)

  @doc """
  Returns a module's name without its application's namespace, its first
  segment: `"Billing.Invoice"` for `Demo.Billing.Invoice`.

  ## Examples

      iex> Clarity.Vertex.Name.in_app(Demo.Billing.Invoice)
      "Billing.Invoice"

      iex> Clarity.Vertex.Name.in_app(Demo)
      "Demo"
  """
  @spec in_app(module()) :: String.t()
  def in_app(module) do
    case Module.split(module) do
      [_app | [_ | _] = rest] -> Enum.join(rest, ".")
      parts -> Enum.join(parts, ".")
    end
  end

  @doc """
  Render sibling `vertices` using the requested `style`, in order.

  As `display/2`, except that in the `:short` style module names that would
  read the same are told apart: each takes the fewest trailing segments of
  its module that no clashing sibling ends in, so `Demo.Billing.Domain` and
  `Demo.Org.Domain` read `Billing.Domain` and `Org.Domain`.
  """
  @spec display_all([Vertex.t()], style()) :: [String.t()]
  def display_all(vertices, :short) do
    segments = Enum.map(vertices, &module_segments/1)
    clashes = segments |> Enum.reject(&is_nil/1) |> Enum.group_by(&List.last/1)

    Enum.zip_with(vertices, segments, fn
      vertex, nil ->
        Vertex.name(vertex)

      _vertex, segments ->
        segments |> unique_suffix(clashes[List.last(segments)]) |> Enum.join(".")
    end)
  end

  def display_all(vertices, style), do: Enum.map(vertices, &display(&1, style))

  # The segments of the vertex's module, when the vertex is named after it.
  @spec module_segments(Vertex.t()) :: [String.t()] | nil
  defp module_segments(vertex) do
    with module when is_atom(module) and not is_nil(module) <- ModuleProvider.module(vertex),
         true <- Vertex.name(vertex) == inspect(module),
         "Elixir." <> _ <- Atom.to_string(module) do
      Module.split(module)
    else
      _ -> nil
    end
  end

  # The fewest trailing segments that no other module in `clash` ends in; a
  # module that ends another keeps all of its segments.
  @spec unique_suffix([String.t()], [[String.t()]]) :: [String.t()]
  defp unique_suffix(segments, clash) do
    others = List.delete(clash, segments)

    Enum.find_value(1..length(segments), segments, fn count ->
      suffix = Enum.take(segments, -count)
      if Enum.all?(others, &(Enum.take(&1, -count) != suffix)), do: suffix
    end)
  end

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
