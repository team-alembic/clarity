defmodule Clarity.Report.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest

  alias Clarity.Report.Components

  @spec doc(Phoenix.LiveView.Rendered.t()) :: LazyHTML.t()
  defp doc(rendered), do: rendered |> rendered_to_string() |> LazyHTML.from_fragment()

  @spec text(LazyHTML.t(), String.t()) :: String.t()
  defp text(doc, selector), do: doc |> LazyHTML.query(selector) |> LazyHTML.text() |> String.split() |> Enum.join(" ")

  describe "status/1" do
    test "counts what there is to do" do
      assigns = %{}

      assert ~H"<Components.status count={3} />" |> doc() |> text(".report-status") == "3 things to do"
      assert ~H"<Components.status count={1} />" |> doc() |> text(".report-status") == "1 thing to do"
    end

    test "says there's nothing to do, as good news" do
      assigns = %{}
      doc = doc(~H"<Components.status count={0} />")

      assert text(doc, ".report-status[data-tone='ok']") == "Nothing to do"
    end

    test "says the checks are still running instead, until they finish" do
      assigns = %{}
      doc = doc(~H|<Components.status count={0} pending="Still checking dependencies…" />|)

      assert text(doc, ".report-status[data-tone='pending']") == "Still checking dependencies…"
    end

    test "adds a line of small print" do
      assigns = %{}

      doc =
        doc(~H"""
        <Components.status count={0}>
          <:meta>Refreshed today</:meta>
        </Components.status>
        """)

      assert text(doc, ".report-status-meta") == "Refreshed today"
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
    test "is closed by default, titled with a count" do
      assigns = %{}

      doc =
        doc(~H"""
        <Components.section id="terms" title="Terms" count={136}>
          <p>Inside</p>
        </Components.section>
        """)

      assert doc |> LazyHTML.query("details#terms.report-section:not([open])") |> Enum.count() == 1
      assert text(doc, "summary") == "Terms 136"
    end
  end

  describe "path/3" do
    test "builds a vertex's path in a lens" do
      lens = %Clarity.Perspective.Lens{id: "architect", name: "Architect", icon: fn -> nil end, filter: true}

      assert Components.path("/c", lens, "ash-resource:x") == "/c/architect/ash-resource:x"
    end
  end
end
