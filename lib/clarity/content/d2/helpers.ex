defmodule Clarity.Content.D2.Helpers do
  @moduledoc """
  Shared helpers used by D2 content providers.

  Provides consistent identifier sanitisation, vertex link formatting, and a
  domain colour palette mirroring the Graphviz Application Diagram so that
  `light` and `dark` themes look intentional across both renderers.
  """

  alias Clarity.Vertex
  alias Clarity.Vertex.Util

  @typedoc "Theme key forwarded from the LiveView."
  @type theme() :: :light | :dark

  @doc """
  Quote a string for use as a D2 label.
  """
  @spec quoted(String.t()) :: iodata()
  def quoted(string) when is_binary(string) do
    escaped = string |> String.replace("\\", "\\\\") |> String.replace(~s|"|, ~s|\\"|)
    [?", escaped, ?"]
  end

  @doc """
  Convert a string into a safe D2 identifier.

  D2 ids permit dots and most ascii, but to keep things simple all non
  alphanumeric characters are collapsed to underscores.
  """
  @spec safe_id(String.t()) :: String.t()
  def safe_id(name) when is_binary(name), do: String.replace(name, ~r/[^A-Za-z0-9]/, "_")

  @doc """
  Last segment of a module name. `Foo.Bar.Baz -> "Baz"`.
  """
  @spec short_name(module()) :: String.t()
  def short_name(module) when is_atom(module), do: module |> Module.split() |> List.last()

  @doc """
  Build the `vertex://...` link string for a Clarity vertex.
  """
  @spec vertex_link(module(), [term()]) :: iodata()
  def vertex_link(vertex_module, args) when is_atom(vertex_module) and is_list(args),
    do: ["vertex://", Util.id(vertex_module, args)]

  @doc """
  Build the `vertex://...` link string for an already-built Clarity vertex.
  """
  @spec vertex_link(struct()) :: iodata()
  def vertex_link(%_{} = vertex), do: ["vertex://", Vertex.id(vertex)]

  @light_palette [
    {"#fef3c7", "#a16207", "#1f2937"},
    {"#dcfce7", "#15803d", "#1f2937"},
    {"#dbeafe", "#1d4ed8", "#1f2937"},
    {"#fce7f3", "#be185d", "#1f2937"},
    {"#ede9fe", "#6d28d9", "#1f2937"},
    {"#ffedd5", "#c2410c", "#1f2937"},
    {"#ffe4e6", "#be123c", "#1f2937"},
    {"#cffafe", "#0e7490", "#1f2937"}
  ]

  @dark_palette [
    {"#854d0e", "#fbbf24", "#fef3c7"},
    {"#166534", "#4ade80", "#dcfce7"},
    {"#1e40af", "#60a5fa", "#dbeafe"},
    {"#9d174d", "#f472b6", "#fce7f3"},
    {"#5b21b6", "#a78bfa", "#ede9fe"},
    {"#9a3412", "#fb923c", "#ffedd5"},
    {"#9f1239", "#fb7185", "#ffe4e6"},
    {"#155e75", "#22d3ee", "#cffafe"}
  ]

  @doc """
  Returns the `{fill, stroke, fg}` colours used for a domain at the given
  index for the requested theme.
  """
  @spec domain_palette(non_neg_integer(), theme()) :: {String.t(), String.t(), String.t()}
  def domain_palette(idx, :light), do: Enum.at(@light_palette, rem(idx, length(@light_palette)))

  def domain_palette(idx, :dark), do: Enum.at(@dark_palette, rem(idx, length(@dark_palette)))

  @doc """
  Neutral `{bg, fg, stroke}` colour set used for default boxes.
  """
  @spec neutral_palette(theme()) :: {String.t(), String.t(), String.t()}
  def neutral_palette(:light), do: {"#ffffff", "#0f172a", "#475569"}
  def neutral_palette(:dark), do: {"#1e293b", "#f8fafc", "#94a3b8"}
end
