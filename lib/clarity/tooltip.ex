defmodule Clarity.Tooltip do
  @moduledoc """
  Builds the hover hints shown by the `Tooltip` JavaScript hook.

  Hints are rendered inline as `data-tooltip-*` attributes, so showing one
  needs no round-trip to the server. There are two flavours:

    * **Vertex hints** carry the vertex name, a type pill (its type label with
      an icon and colour tone), a one-line summary derived from
      `Clarity.Vertex.TooltipProvider`, and the badges and facts from
      `Clarity.Vertex.HintProvider`.
    * **Label hints** carry a single line of text, for icon buttons, badges
      and other chrome.

  The full `Clarity.Vertex.TooltipProvider` markdown is reduced to its first
  prose paragraph as plain text (see `summarise/1`); the complete content
  remains available in the content panel.
  """

  alias Clarity.Vertex
  alias Clarity.Vertex.HintProvider
  alias Clarity.Vertex.TooltipProvider

  @max_length 160
  @max_facts 5
  @max_value_length 60
  @max_chips 6

  # Each icon's colour tone groups vertex types by the role they play.
  @tones %{
    action: "behaviour",
    advisory: "warning",
    aggregate: "behaviour",
    application: "structure",
    attribute: "data",
    calculation: "behaviour",
    data_layer: "structure",
    domain: "structure",
    dsl: "dsl",
    endpoint: "web",
    entity: "dsl",
    extension: "dsl",
    generic: "neutral",
    module: "structure",
    policy: "rule",
    relationship: "data",
    resource: "structure",
    router: "web",
    section: "dsl",
    type: "data"
  }

  @typedoc "A hint for one vertex, as consumed by the `Tooltip` hook."
  @type hint() :: %{
          required(:title) => String.t(),
          required(:type) => String.t(),
          required(:icon) => String.t(),
          required(:tone) => String.t(),
          optional(:badges) => [String.t()],
          optional(:text) => String.t(),
          optional(:facts) => [[String.t() | [String.t()]]]
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
      "data-tooltip-type": hint.type,
      "data-tooltip-icon": hint.icon,
      "data-tooltip-tone": hint.tone
    ] ++
      for {key, attr, encode} <- [
            {:badges, :"data-tooltip-badges", &JSON.encode!/1},
            {:text, :"data-tooltip-text", & &1},
            {:facts, :"data-tooltip-facts", &JSON.encode!/1}
          ],
          Map.has_key?(hint, key),
          do: {attr, encode.(hint[key])}
  end

  @doc """
  Maps vertex ids to hints, for vertices with a summary, badges or facts.

  Used for graph visualisations, where the node labels already show the name
  and type, so a hint with nothing more would add nothing.
  """
  @spec hints(Enumerable.t(Vertex.t())) :: %{String.t() => hint()}
  def hints(vertices) do
    for vertex <- vertices,
        hint = hint(vertex),
        Enum.any?([:badges, :text, :facts], &Map.has_key?(hint, &1)),
        into: %{} do
      {Vertex.id(vertex), hint}
    end
  end

  @doc """
  Returns the hint for one vertex.

  Shows at most #{@max_facts} facts; values longer than #{@max_value_length} characters are
  truncated, and lists beyond #{@max_chips} items end in a "+N more" chip. Empty
  badges, summary and facts are left out.
  """
  @spec hint(Vertex.t()) :: hint()
  def hint(vertex) do
    vertex
    |> type_icon()
    |> Map.merge(%{title: Vertex.name(vertex), type: Vertex.type_label(vertex)})
    |> put_present(:badges, HintProvider.badges(vertex))
    |> put_present(:text, vertex |> TooltipProvider.tooltip() |> summarise())
    |> put_present(
      :facts,
      vertex |> HintProvider.facts() |> Enum.take(@max_facts) |> Enum.map(&fact/1)
    )
  end

  @doc """
  Returns the icon and colour tone of a vertex's type, as shown on its type
  pill, without building the rest of the hint.
  """
  @spec type_icon(Vertex.t()) :: %{icon: String.t(), tone: String.t()}
  def type_icon(vertex) do
    icon = vertex |> HintProvider.icon() |> known_icon()

    %{icon: Atom.to_string(icon), tone: Map.fetch!(@tones, icon)}
  end

  @doc """
  Lists the icons a `Clarity.Vertex.HintProvider` can choose from.

  Any other icon falls back to `:generic`.
  """
  @spec icons() :: [HintProvider.icon()]
  def icons, do: Map.keys(@tones)

  @spec known_icon(atom()) :: HintProvider.icon()
  defp known_icon(icon) when is_map_key(@tones, icon), do: icon
  defp known_icon(_icon), do: :generic

  @spec put_present(map(), atom(), term()) :: map()
  defp put_present(map, _key, empty) when empty in [nil, []], do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)

  @spec fact(HintProvider.fact()) :: [String.t() | [String.t()]]
  defp fact({label, values}) when is_list(values) do
    {shown, hidden} = Enum.split(values, @max_chips)
    more = if hidden == [], do: [], else: ["+#{length(hidden)} more"]
    [label, Enum.map(shown, &cap/1) ++ more]
  end

  defp fact({label, value}), do: [label, cap(value)]

  @spec cap(String.t()) :: String.t()
  defp cap(value) do
    if String.length(value) <= @max_value_length,
      do: value,
      else: String.slice(value, 0, @max_value_length - 1) <> "…"
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
