defmodule Clarity.Tooltip do
  @moduledoc """
  Builds the hover hints shown by the `Tooltip` JavaScript hook.

  Hints are rendered inline as `data-tooltip-*` attributes, so showing one
  needs no round-trip to the server. There are two flavours:

    * **Vertex hints** carry the vertex name, its type label and a one-line
      summary derived from `Clarity.Vertex.TooltipProvider`.
    * **Label hints** carry a single line of text, for icon buttons, badges
      and other chrome.

  The full `Clarity.Vertex.TooltipProvider` markdown is reduced to its first
  prose paragraph as plain text (see `summarise/1`); the complete content
  remains available in the content panel.
  """

  alias Clarity.Vertex
  alias Clarity.Vertex.TooltipProvider

  @max_length 160

  @typedoc "A hint for one vertex, as consumed by the `Tooltip` hook."
  @type hint() :: %{
          required(:title) => String.t(),
          required(:type) => String.t(),
          optional(:text) => String.t()
        }

  @doc """
  Returns the `data-tooltip-*` attributes for a vertex or a plain label.

  Spread the result into a HEEx tag: `<a {Clarity.Tooltip.attrs(@vertex)}>`.

  ## Examples

      iex> Clarity.Tooltip.attrs("Copy to clipboard")
      ["data-tooltip-text": "Copy to clipboard"]

  """
  @spec attrs(Vertex.t() | String.t() | nil) :: keyword(String.t())
  def attrs(nil), do: []
  def attrs(label) when is_binary(label), do: ["data-tooltip-text": label]

  def attrs(vertex) do
    hint = hint(vertex)

    [
      "data-tooltip-title": hint.title,
      "data-tooltip-type": hint.type
    ] ++ if(text = hint[:text], do: ["data-tooltip-text": text], else: [])
  end

  @doc """
  Maps vertex ids to hints, for vertices that have a summary.

  Used for graph visualisations, where the node labels already show the name
  and type, so a hint without a summary would add nothing.
  """
  @spec hints(Enumerable.t(Vertex.t())) :: %{String.t() => hint()}
  def hints(vertices) do
    for vertex <- vertices, hint = hint(vertex), Map.has_key?(hint, :text), into: %{} do
      {Vertex.id(vertex), hint}
    end
  end

  @spec hint(Vertex.t()) :: hint()
  defp hint(vertex) do
    hint = %{title: Vertex.name(vertex), type: Vertex.type_label(vertex)}

    case vertex |> TooltipProvider.tooltip() |> summarise() do
      nil -> hint
      text -> Map.put(hint, :text, text)
    end
  end

  @doc """
  Reduces tooltip markdown to a one-line plain-text summary.

  Takes the first prose paragraph — skipping identity lines made only of
  inline code, `Key: value` meta lines, headings and lists — strips inline
  markdown, collapses whitespace and truncates to #{@max_length} characters on a
  word boundary. Returns `nil` when there is no prose to show.

  ## Examples

      iex> Clarity.Tooltip.summarise("`MyApp.User`\\n\\nDomain: `MyApp.Accounts`\\n\\nA **staff** login.")
      "A staff login."

      iex> Clarity.Tooltip.summarise("`MyAppWeb.Endpoint`\\n\\nURL: http://localhost:4000")
      nil

  """
  @spec summarise(iodata() | nil) :: String.t() | nil
  def summarise(nil), do: nil

  def summarise(markdown) do
    markdown
    |> IO.iodata_to_binary()
    |> String.split(~r/\n\s*\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.find(&prose?/1)
    |> case do
      nil -> nil
      paragraph -> paragraph |> to_plain_text() |> truncate()
    end
  end

  @spec prose?(String.t()) :: boolean()
  defp prose?(""), do: false

  defp prose?(paragraph) do
    not (heading?(paragraph) or list?(paragraph) or code_only?(paragraph) or
           meta?(paragraph))
  end

  @spec heading?(String.t()) :: boolean()
  defp heading?(paragraph), do: String.starts_with?(paragraph, "#")

  @spec list?(String.t()) :: boolean()
  defp list?(paragraph), do: Regex.match?(~r/^([-*+]|\d+\.)\s/, paragraph)

  @spec code_only?(String.t()) :: boolean()
  defp code_only?(paragraph), do: Regex.match?(~r/^(`[^`]*`\s*)+$/, paragraph)

  # "Domain: `X`", "**Severity:** high", "Attribute: `x` on Resource: `Y`"
  @spec meta?(String.t()) :: boolean()
  defp meta?(paragraph) do
    Regex.match?(~r/^[A-Za-z][\w ]{0,40}:(\s|$)/, strip_emphasis(paragraph))
  end

  @spec to_plain_text(String.t()) :: String.t()
  defp to_plain_text(paragraph) do
    paragraph
    |> then(&Regex.replace(~r/!?\[([^\]]*)\]\([^)]*\)/, &1, "\\1"))
    |> then(&Regex.replace(~r/`([^`]*)`/, &1, "\\1"))
    |> strip_emphasis()
    |> then(&Regex.replace(~r/\s+/, &1, " "))
    |> String.trim()
  end

  @spec strip_emphasis(String.t()) :: String.t()
  defp strip_emphasis(text) do
    text
    |> then(&Regex.replace(~r/(\*\*|__)(.+?)\1/, &1, "\\2"))
    |> then(&Regex.replace(~r/\*([^*\s][^*]*)\*/, &1, "\\1"))
  end

  @spec truncate(String.t()) :: String.t()
  defp truncate(text) do
    if String.length(text) <= @max_length do
      text
    else
      cut = String.slice(text, 0, @max_length)
      next = String.at(text, @max_length)

      cut =
        if next =~ ~r/\s/ do
          cut
        else
          Regex.replace(~r/\s+\S*$/, cut, "")
        end

      String.trim_trailing(cut) <> "…"
    end
  end
end
