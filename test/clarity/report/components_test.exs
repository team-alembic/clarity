defmodule Clarity.Report.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest

  alias Clarity.Perspective.Lens
  alias Clarity.Report.Action
  alias Clarity.Report.Components

  @spec doc(Phoenix.LiveView.Rendered.t()) :: LazyHTML.t()
  defp doc(rendered), do: rendered |> rendered_to_string() |> LazyHTML.from_fragment()

  @spec text(LazyHTML.t(), String.t()) :: String.t()
  defp text(doc, selector), do: doc |> LazyHTML.query(selector) |> LazyHTML.text() |> String.split() |> Enum.join(" ")

  @spec tally(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: Action.tally()
  defp tally(high, medium, low) do
    Action.sum([%{high: high, medium: medium, low: low, total: high + medium + low, worst: nil}])
  end

  describe "status/1" do
    test "counts what there is to do, and how many at each severity" do
      assigns = %{tally: tally(2, 18, 6)}
      doc = doc(~H"<Components.status tally={@tally} />")

      assert text(doc, ".report-status > span:first-of-type") == "26 things to do"

      assert doc
             |> LazyHTML.query(".report-tally")
             |> Enum.map(&{LazyHTML.attribute(&1, "data-severity"), LazyHTML.text(&1)})
             |> Enum.map(fn {[severity], text} -> {severity, text |> String.split() |> Enum.join(" ")} end) ==
               [{"high", "2 high"}, {"medium", "18 medium"}, {"low", "6 low"}]
    end

    test "leaves out the severities with nothing to do" do
      assigns = %{tally: tally(0, 1, 0)}
      doc = doc(~H"<Components.status tally={@tally} />")

      assert text(doc, ".report-status > span:first-of-type") == "1 thing to do"
      assert text(doc, ".report-tally") == "1 medium"
    end

    test "says there's nothing to do, as good news" do
      assigns = %{tally: tally(0, 0, 0)}
      doc = doc(~H"<Components.status tally={@tally} />")

      assert text(doc, ".report-status[data-tone='ok']") == "Nothing to do"
    end

    test "links to where the to-dos are listed" do
      assigns = %{tally: tally(1, 0, 0)}
      doc = doc(~H|<Components.status tally={@tally} patch="/c/actions/x" />|)

      assert text(doc, "a.report-status-link[href='/c/actions/x']") == "1 thing to do →"
    end

    test "says the checks are still running instead, until they finish" do
      assigns = %{tally: tally(0, 0, 0)}
      doc = doc(~H|<Components.status tally={@tally} pending="Still checking dependencies…" />|)

      assert text(doc, ".report-status[data-tone='pending']") == "Still checking dependencies…"
    end

    test "adds a line of small print" do
      assigns = %{tally: tally(0, 0, 0)}

      doc =
        doc(~H"""
        <Components.status tally={@tally}>
          <:meta>Refreshed today</:meta>
        </Components.status>
        """)

      assert text(doc, ".report-status-meta") == "Refreshed today"
    end
  end

  describe "count_badge/1" do
    test "counts the to-dos, tinted by the most severe" do
      assigns = %{tally: tally(0, 3, 4)}
      doc = doc(~H"<Components.count_badge tally={@tally} />")

      assert text(doc, ".count-badge[data-severity='medium']") == "7"
    end

    test "shows nothing with nothing to do, or while counting" do
      assigns = %{tally: tally(0, 0, 0)}

      assert ~H"<Components.count_badge tally={@tally} />" |> doc() |> LazyHTML.query(".count-badge") |> Enum.empty?()
      assert ~H"<Components.count_badge tally={nil} />" |> doc() |> LazyHTML.query(".count-badge") |> Enum.empty?()
    end
  end

  describe "actions/1" do
    setup do
      actions = [
        %Action{
          severity: :high,
          title: "Sensitive fields anyone can read",
          fix: "Add a field policy, or use `public? false`.",
          groups: [%{label: "Helpdesk.CustomerContact", id: "r", items: [%{text: "email", id: "f"}, %{text: "phone"}]}]
        },
        %Action{
          severity: :low,
          title: "Behind their latest release",
          command: "mix deps.update pubsub",
          layout: :lines,
          groups: [
            %{items: [%{text: "pubsub", id: "a", note: "2.3.0 → 2.4.0 via phoenix", details: ["GHSA-1 · A hole"]}]}
          ]
        }
      ]

      assigns = %{actions: actions, lens: %Lens{id: "architect", name: "Architect", icon: fn -> nil end, filter: true}}
      %{doc: doc(~H|<Components.actions actions={@actions} prefix="/c" lens={@lens} />|)}
    end

    test "shows each action as a to-do, counting its items", %{doc: doc} do
      assert text(doc, ".report-todo[data-severity='high'] .report-todo-count") == "2"
      assert text(doc, ".report-todo[data-severity='low'] .report-todo-count") == "1"
    end

    test "groups items beside what they belong to, linked to their pages", %{doc: doc} do
      assert text(doc, ".report-todo-group-label a[href='/c/architect/r']") == "Helpdesk.CustomerContact"
      assert text(doc, ".report-todo-group-items a.report-chip[href='/c/architect/f']") == "email"
      assert text(doc, ".report-todo-group-items span.report-chip") == "phone"
    end

    test "puts each item on a line of its own, with its note and details, in the lines layout", %{doc: doc} do
      line = text(doc, ".report-todo-line")

      assert line =~ "pubsub 2.3.0 → 2.4.0 via phoenix"
      assert line =~ "GHSA-1 · A hole"
      assert text(doc, ".report-command code") == "mix deps.update pubsub"
    end

    test "shows the fix with code between backticks, and no gaps around it", %{doc: doc} do
      assert doc |> LazyHTML.query(".report-todo-fix") |> Enum.at(0) |> LazyHTML.to_html() =~
               "Add a field policy, or use <code>public? false</code>."
    end
  end

  describe "todo/1" do
    test "shows the severity, the problem, what it affects and the fix" do
      assigns = %{}

      doc =
        doc(~H"""
        <Components.todo severity={:high} title="Sensitive fields anyone can read" count={2}>
          <Components.chip>email</Components.chip>
          <:fix>Add a field policy.</:fix>
        </Components.todo>
        """)

      assert text(doc, ".report-todo[data-severity='high'] .report-severity") == "High"
      assert text(doc, ".report-todo-title") =~ "Sensitive fields anyone can read"
      assert text(doc, ".report-todo-count") == "2"
      assert text(doc, ".report-todo-affects .report-chip") == "email"
      assert text(doc, ".report-todo-fix") == "Add a field policy."
    end

    test "offers a command to copy" do
      assigns = %{}

      doc =
        doc(~H"""
        <Components.todo severity={:low} title="Outdated" command="mix deps.update a b" />
        """)

      assert text(doc, ".report-command code") == "mix deps.update a b"

      assert doc
             |> LazyHTML.query(".report-command button.copy-button[aria-label='Copy command']")
             |> Enum.count() == 1
    end
  end

  describe "chip/1" do
    test "links to a vertex when given a path, as a patch" do
      assigns = %{}
      doc = doc(~H|<Components.chip patch="/c/architect/x">x</Components.chip>|)

      assert doc |> LazyHTML.query("a.report-chip[href='/c/architect/x'][data-phx-link='patch']") |> Enum.count() == 1
    end
  end

  describe "section/1" do
    test "is open by default, titled with a count" do
      assigns = %{}

      doc =
        doc(~H"""
        <Components.section id="terms" title="Terms" count={136}>
          <p>Inside</p>
        </Components.section>
        """)

      assert doc |> LazyHTML.query("details#terms.report-section[open]") |> Enum.count() == 1
      assert text(doc, "summary") == "Terms 136"
    end
  end

  describe "path/3" do
    test "builds a vertex's path in a lens" do
      lens = %Lens{id: "architect", name: "Architect", icon: fn -> nil end, filter: true}

      assert Components.path("/c", lens, "ash-resource:x") == "/c/architect/ash-resource:x"
    end
  end
end
