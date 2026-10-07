defmodule Clarity.TooltipTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.Test.HintVertex
  alias Clarity.Tooltip
  alias Clarity.Vertex
  alias Demo.Accounts.User

  doctest Tooltip

  describe inspect(&Tooltip.summarise/1) do
    test "returns nil for nil and blank content" do
      assert Tooltip.summarise(nil) == nil
      assert Tooltip.summarise("") == nil
      assert Tooltip.summarise("  \n\n  ") == nil
    end

    test "skips a leading identity line made only of inline code" do
      markdown = "`Demo.Accounts.User`\n\nA user of the system."

      assert Tooltip.summarise(markdown) == "A user of the system."
    end

    test "skips `Key: value` meta lines, bold or not" do
      markdown = """
      `Demo.Accounts.User`

      Domain: `Demo.Accounts`

      **Severity:** high

      Attribute: `name` on Resource: `Demo.Accounts.User`

      The first real sentence.
      """

      assert Tooltip.summarise(markdown) == "The first real sentence."
    end

    test "skips headings and lists" do
      markdown = """
      ## Arguments

      - `id` (`:uuid`)
      * Type: `:string`
      1. step one

      Prose after the structure.
      """

      assert Tooltip.summarise(markdown) == "Prose after the structure."
    end

    test "returns nil when there is no prose paragraph" do
      markdown = "`DemoWeb.Endpoint`\n\nURL: http://localhost:4000"

      assert Tooltip.summarise(markdown) == nil
    end

    test "strips inline markdown to plain text" do
      markdown =
        "Uses **bold**, __strong__, *emphasis*, `code` and [a link](https://example.com) " <>
          "plus ![an image](img.png) and snake_case_names."

      assert Tooltip.summarise(markdown) ==
               "Uses bold, strong, emphasis, code and a link plus an image and snake_case_names."
    end

    test "collapses line breaks inside the paragraph" do
      markdown = "A summary that\nwraps across\n  several lines."

      assert Tooltip.summarise(markdown) == "A summary that wraps across several lines."
    end

    test "truncates long text on a word boundary with an ellipsis" do
      words = String.duplicate("word ", 50)

      summary = Tooltip.summarise(words)

      # 160 chars at most, cut after a whole word, with the ellipsis appended
      assert summary == "word " |> String.duplicate(32) |> String.trim_trailing() |> Kernel.<>("…")
      assert String.length(summary) <= 161
    end

    test "leaves text at the limit untouched" do
      text = String.duplicate("a", 160)

      assert Tooltip.summarise(text) == text
    end

    test "accepts iodata" do
      assert Tooltip.summarise(["`X`", "\n\n", ["Some ", "prose."]]) == "Some prose."
    end
  end

  describe inspect(&Tooltip.attrs/1) do
    test "a vertex yields its name, type pill, summary and facts" do
      vertex = %Vertex.Application{
        app: :demo,
        description: "Demo application for Clarity.",
        version: "1.0.0"
      }

      assert Tooltip.attrs(vertex) == [
               "data-tooltip-title": "demo",
               "data-tooltip-type": "Application",
               "data-tooltip-icon": "application",
               "data-tooltip-tone": "structure",
               "data-tooltip-text": "Demo application for Clarity.",
               "data-tooltip-facts": ~s([["Version","1.0.0"]])
             ]
    end

    test "badges are encoded as a JSON list" do
      vertex = %Vertex.Module{module: Clarity.Server, behaviour?: true}

      assert Keyword.fetch!(Tooltip.attrs(vertex), :"data-tooltip-badges") == ~s(["behaviour"])
    end

    test "list facts are encoded as JSON lists" do
      vertex = %Vertex.Ash.Action{action: Info.action(User, :by_name), resource: User}

      assert vertex |> Tooltip.attrs() |> Keyword.fetch!(:"data-tooltip-facts") |> JSON.decode!() == [
               ["Resource", "Demo.Accounts.User"],
               ["Type", "read"],
               ["Arguments", ["first_name", "last_name"]]
             ]
    end

    test "a vertex with nothing more to say gets a title, type and a generic icon" do
      vertex = %Vertex.Root{}

      assert Tooltip.attrs(vertex) == [
               "data-tooltip-title": "Root",
               "data-tooltip-type": "Root",
               "data-tooltip-icon": "generic",
               "data-tooltip-tone": "neutral"
             ]
    end

    test "nil yields no attributes, so optional labels can be passed straight through" do
      assert Tooltip.attrs(nil) == []
    end

    test "a string yields a plain label hint" do
      assert Tooltip.attrs("Copy to clipboard") == ["data-tooltip-text": "Copy to clipboard"]
    end
  end

  describe inspect(&Tooltip.hint/1) do
    test "caps facts at five, long values at 60 characters and lists at six chips" do
      long = String.duplicate("x", 80)
      many = Enum.map(1..9, &"arg#{&1}")
      facts = [{"Long", long}, {"Many", many}] ++ Enum.map(1..6, &{"F#{&1}", "v"})

      hint = Tooltip.hint(%HintVertex{facts: facts})

      assert length(hint.facts) == 5
      assert [["Long", value], ["Many", chips] | _rest] = hint.facts
      assert value == String.duplicate("x", 59) <> "…"
      assert chips == ["arg1", "arg2", "arg3", "arg4", "arg5", "arg6", "+3 more"]
    end

    test "an icon outside Clarity's set falls back to the generic icon" do
      assert %{icon: "generic", tone: "neutral"} = Tooltip.hint(%HintVertex{icon: :unheard_of})
    end
  end

  describe inspect(&Tooltip.type_icon/1) do
    test "gives the icon and colour tone of the vertex's type" do
      assert Tooltip.type_icon(%Vertex.Ash.Resource{resource: User}) ==
               %{icon: "resource", tone: "structure"}
    end

    test "an icon outside Clarity's set falls back to the generic icon" do
      assert Tooltip.type_icon(%HintVertex{icon: :unheard_of}) ==
               %{icon: "generic", tone: "neutral"}
    end
  end

  describe inspect(&Tooltip.icons/0) do
    test "lists every icon a HintProvider can choose" do
      assert :resource in Tooltip.icons()
      assert :generic in Tooltip.icons()
    end
  end

  describe inspect(&Tooltip.hints/1) do
    test "maps vertex ids to hints, for vertices with a summary, badges or facts" do
      app = %Vertex.Application{app: :demo, description: "", version: "1.0.0"}
      root = %Vertex.Root{}

      assert Tooltip.hints([app, root]) == %{
               Vertex.id(app) => %{
                 title: "demo",
                 type: "Application",
                 icon: "application",
                 tone: "structure",
                 facts: [["Version", "1.0.0"]]
               }
             }
    end
  end
end
