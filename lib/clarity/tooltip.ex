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
    reactor: "behaviour",
    relationship: "data",
    resource: "structure",
    router: "web",
    section: "dsl",
    type: "data"
  }

  # What badges say, wherever they're shown: on hover hints and as overview
  # flags. Each has a kind, which colours it the same everywhere, and a line
  # that explains it.
  @badges %{
    "always" => {:danger, "Allowed for this actor whatever the checks: open to them"},
    "argument" => {:plain, "An input of the action's own, not an attribute of its resource"},
    "async" => {:plain, "Computed in a process of its own"},
    "bypass" => {:danger, "A bypass policy: when it passes, the rest are skipped"},
    "change" => {:plain, "Changes the record as the action runs"},
    "code reloading" => {:muted, "Recompiles changed code on each request, as in development"},
    "conditional" => {:good, "Allowed for this actor when the policies' checks pass at runtime"},
    "dev" => {:muted, "Only development builds run it"},
    "embedded" => {:plain, "Stored inside other resources' attributes, not on its own"},
    "exposed" => {:danger, "Sensitive, yet public with no field policy to restrict who reads it"},
    "generated" => {:muted, "Given its value by the data layer"},
    "gets one" => {:plain, "Returns one record, not a list"},
    "includes nil" => {:plain, "Counts nil values too"},
    "live" => {:plain, "A LiveView: rendered once over HTTP, then kept live over its socket"},
    "manual" => {:warn, "Carried out by a module of its own"},
    "multitenant" => {:warn, "Keeps each tenant's records apart"},
    "never" => {:muted, "Never allowed for this actor"},
    "no policies" => {:warn, "No policy authorizer: Ash policies don't restrict it"},
    "prepare" => {:plain, "Shapes the query before it runs: its filter, sort or loads"},
    "primary" => {:key, "The action of its type that Ash uses unless told otherwise"},
    "primary key" => {:key, "Part of the resource's primary key"},
    "private" => {:muted, "Hidden from public interfaces, such as APIs"},
    "protected" => {:good, "Sensitive, and private or decided by a field policy"},
    "public" => {:good, "Shown to public interfaces, such as APIs"},
    "read-only" => {:muted, "No action writes it"},
    "required" => {:warn, "Must have a value: it doesn't allow nil"},
    "sensitive" => {:danger, "Holds sensitive data, kept out of logs and inspection"},
    "soft" => {:warn, "Marks records destroyed instead of deleting them"},
    "unique values" => {:plain, "Counts each distinct value once"},
    "unknown" => {:plain, "Couldn't be worked out: the action failed on empty input"},
    "unrestricted" => {:danger, "No policy applies to it: allowed for anyone"},
    "upsert" => {:warn, "Updates the record with the same identity, when there is one"},
    "validate" => {:good, "Checks the input, and stops the action when it fails"}
  }

  @typedoc "How a badge is coloured, the same on hover hints and overview flags."
  @type badge_kind() :: :plain | :key | :good | :warn | :danger | :muted

  @typedoc "A hint for one vertex, as consumed by the `Tooltip` hook."
  @type hint() :: %{
          required(:title) => String.t(),
          required(:type) => String.t(),
          required(:icon) => String.t(),
          required(:tone) => String.t(),
          optional(:badges) => [String.t() | [String.t()]],
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
    |> Map.merge(%{title: Vertex.name(vertex), type: type_name(vertex)})
    |> put_present(:badges, vertex |> HintProvider.badges() |> Enum.map(&coloured/1))
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
  Returns a vertex type's name for people, after its icon: `Resource`,
  `Data layer`. A vertex with the generic icon is named by its type label.

  ## Examples

      iex> Clarity.Tooltip.type_name(%Clarity.Vertex.Ash.Domain{domain: Demo.Accounts})
      "Domain"

  """
  @spec type_name(Vertex.t()) :: String.t()
  def type_name(vertex) do
    case type_icon(vertex).icon do
      "generic" -> Vertex.type_label(vertex)
      "dsl" -> "DSL"
      icon -> icon |> String.replace("_", " ") |> String.capitalize()
    end
  end

  @doc """
  Lists the icons a `Clarity.Vertex.HintProvider` can choose from.

  Any other icon falls back to `:generic`.
  """
  @spec icons() :: [HintProvider.icon()]
  def icons, do: Map.keys(@tones)

  @doc """
  Returns how a badge is coloured and what explains it, the same wherever
  it's shown. Badges Clarity doesn't know are plain, with no explanation.

  ## Examples

      iex> Clarity.Tooltip.badge("required")
      %{kind: :warn, hint: "Must have a value: it doesn't allow nil"}

      iex> Clarity.Tooltip.badge("beta")
      %{kind: :plain, hint: nil}

  """
  @spec badge(String.t()) :: %{kind: badge_kind(), hint: String.t() | nil}
  def badge(text) do
    case Map.fetch(@badges, text) do
      {:ok, {kind, hint}} -> %{kind: kind, hint: hint}
      :error -> %{kind: :plain, hint: nil}
    end
  end

  # A badge for the Tooltip hook: its text, with its kind when it has one.
  @spec coloured(String.t()) :: String.t() | [String.t()]
  defp coloured(text) do
    case badge(text) do
      %{kind: :plain} -> text
      %{kind: kind} -> [text, Atom.to_string(kind)]
    end
  end

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
