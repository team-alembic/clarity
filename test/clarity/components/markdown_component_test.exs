defmodule Clarity.Components.MarkdownComponentTest do
  use ExUnit.Case, async: true

  import Clarity.Components.MarkdownComponent
  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias Clarity.Perspective.Lens

  @spec test_lens(String.t()) :: Lens.t()
  defp test_lens(id) do
    %Lens{
      id: id,
      name: "Test Lens",
      icon: fn ->
        assigns = %{}
        ~H"<span>icon</span>"
      end,
      filter: fn _ -> true end
    }
  end

  @spec render_markdown(assigns :: map()) :: String.t()
  defp render_markdown(assigns) do
    rendered_to_string(~H"""
    <.markdown content={@content} prefix={@prefix} lens={@lens} class={@class} />
    """)
  end

  describe "markdown/1" do
    test "renders basic markdown without vertex links" do
      html =
        render_markdown(%{
          content: "# Hello World\n\nThis is a test.",
          prefix: "/clarity",
          lens: test_lens("test"),
          class: "test-class"
        })

      assert html =~ "Hello World"
      assert html =~ "This is a test."
      assert html =~ "prose dark:prose-invert test-class"
    end

    test "transforms vertex:// links to clarity paths" do
      html =
        render_markdown(%{
          content: "Check out [MyApp.User](vertex://resource:MyApp.User) resource.",
          prefix: "/clarity",
          lens: test_lens("debug"),
          class: ""
        })

      assert html =~ ~s[href="/clarity/debug/resource:MyApp.User"]
      assert html =~ ~s[data-phx-link="patch"]
      assert html =~ ~s[data-phx-link-state="push"]
      assert html =~ ">MyApp.User</a>"
    end

    test "handles multiple vertex:// links" do
      html =
        render_markdown(%{
          content: """
          Resource: [MyApp.User](vertex://resource:MyApp.User)
          Domain: [MyApp.Domain](vertex://domain:MyApp.Domain)
          """,
          prefix: "/clarity",
          lens: test_lens("overview"),
          class: ""
        })

      assert html =~ ~s[href="/clarity/overview/resource:MyApp.User"]
      assert html =~ ~s[href="/clarity/overview/domain:MyApp.Domain"]
      assert html =~ ~s[data-phx-link="patch"]
      assert html =~ ~s[data-phx-link-state="push"]
    end

    test "leaves non-vertex links unchanged" do
      html =
        render_markdown(%{
          content: "Visit [Google](https://google.com) for search.",
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ ~s[href="https://google.com"]
      refute html =~ ~s[data-phx-link="patch"]
      refute html =~ ~s[data-phx-link-state="push"]
    end

    test "handles iodata content" do
      html =
        render_markdown(%{
          content: ["# Title\n\n", "Link: [Resource](vertex://resource:Test)"],
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ "Title"
      assert html =~ ~s[href="/clarity/test/resource:Test"]
      assert html =~ ~s[data-phx-link="patch"]
      assert html =~ ~s[data-phx-link-state="push"]
    end

    test "highlights Elixir code blocks" do
      html =
        render_markdown(%{
          content: """
          Here's some Elixir code:

          ```elixir
          defmodule Test do
            def hello, do: :world
          end
          ```
          """,
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ ~r/class="(?:lumis )?highlight"/
      assert html =~ ~s[class="language-elixir"]
      assert html =~ ~s[class="keyword"]
      assert html =~ "defmodule"
      assert html =~ "Test"
      assert html =~ "hello"
    end

    test "highlights code blocks without language as plaintext" do
      html =
        render_markdown(%{
          content: """
          Plain code block:

          ```
          some plain code
          without highlighting
          ```
          """,
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ ~r/class="(?:lumis )?highlight"/
      assert html =~ "some plain code"
      assert html =~ "without highlighting"
    end

    test "highlights Python code blocks" do
      html =
        render_markdown(%{
          content: """
          Python code block:

          ```python
          def hello():
              return "world"
          ```
          """,
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ ~r/class="(?:lumis )?highlight"/
      assert html =~ ~s[class="language-python"]
      assert html =~ "def"
      assert html =~ "hello"
    end

    test "highlights Erlang code blocks" do
      html =
        render_markdown(%{
          content: """
          Here's some Erlang code:

          ```erlang
          -module(test).
          -export([hello/0]).
          hello() -> world.
          ```
          """,
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ ~r/class="(?:lumis )?highlight"/
      assert html =~ ~s[class="language-erlang"]
      assert html =~ "module"
      assert html =~ "test"
    end

    test "handles both highlighting and vertex links together" do
      html =
        render_markdown(%{
          content: """
          Check the [MyApp.User](vertex://resource:MyApp.User) resource:

          ```elixir
          defmodule MyApp.User do
            use Ash.Resource
          end
          ```
          """,
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ ~s[href="/clarity/test/resource:MyApp.User"]
      assert html =~ ~s[data-phx-link="patch"]
      assert html =~ ~r/class="(?:lumis )?highlight"/
      assert html =~ "defmodule"
      assert html =~ "MyApp.User"
    end

    test "vertex links with special characters in IDs" do
      html =
        render_markdown(%{
          content: "[Demo.Accounts.User](vertex://ash-resource:Elixir.Demo.Accounts.User)",
          prefix: "/clarity",
          lens: test_lens("architect"),
          class: ""
        })

      assert html =~ ~s[href="/clarity/architect/ash-resource:Elixir.Demo.Accounts.User"]
      assert html =~ ~s[data-phx-link="patch"]
    end

    test "vertex links inside lists" do
      html =
        render_markdown(%{
          content: """
          - [User](vertex://resource:User)
          - [Domain](vertex://domain:Domain)
          """,
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ ~s[href="/clarity/test/resource:User"]
      assert html =~ ~s[href="/clarity/test/domain:Domain"]
      assert html =~ ~s[data-phx-link="patch"]
    end

    test "mixed vertex and external links" do
      html =
        render_markdown(%{
          content: """
          See [User](vertex://resource:User) and [Ash docs](https://ash-hq.org).
          """,
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ ~s[href="/clarity/test/resource:User" data-phx-link="patch"]
      assert html =~ ~s[href="https://ash-hq.org"]
      refute html =~ ~s[href="https://ash-hq.org" data-phx-link]
    end

    test "empty content renders without error" do
      html =
        render_markdown(%{
          content: "",
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ "prose dark:prose-invert"
    end

    test "does not rewrite vertex:// inside an inline code span" do
      html =
        render_markdown(%{
          content: "Use the `vertex://resource:User` scheme.",
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ "vertex://resource:User"
      refute html =~ ~s[data-phx-link="patch"]
      refute html =~ ~s[href="/clarity/test/resource:User"]
    end

    test "does not rewrite vertex:// inside a fenced code block" do
      html =
        render_markdown(%{
          content: """
          ```
          [User](vertex://resource:User)
          ```
          """,
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ "vertex://resource:User"
      refute html =~ ~s[data-phx-link="patch"]
      refute html =~ ~s[href="/clarity/test/resource:User"]
    end

    test "preserves the title attribute on vertex:// links" do
      html =
        render_markdown(%{
          content: ~s{[User](vertex://resource:User "User resource")},
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ ~s[href="/clarity/test/resource:User"]
      assert html =~ ~s[title="User resource"]
      assert html =~ ~s[data-phx-link="patch"]
    end

    test "escapes special characters when building the vertex href" do
      html =
        render_markdown(%{
          content: ~s{[x](vertex://resource:a"b)},
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ "a&quot;b"
      refute html =~ ~s[resource:a"b"]
    end

    test "escapes special characters in the vertex:// link title" do
      html =
        render_markdown(%{
          content: ~s{[x](vertex://resource:User "a<b&c")},
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ "a&lt;b&amp;c"
      refute html =~ ~s[title="a<b&c"]
    end

    test "preserves inline formatting inside vertex:// link text" do
      html =
        render_markdown(%{
          content: "[**Bold** and `code`](vertex://resource:User)",
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ ~s[data-phx-link="patch"]
      assert html =~ "<strong>Bold</strong>"
      assert html =~ "<code>code</code>"
    end

    test "omits raw HTML in content (no passthrough)" do
      html =
        render_markdown(%{
          content: "Hello <script>alert('xss')</script> there",
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      refute html =~ "<script>"
      assert html =~ "Hello"
    end

    test "renders an error notice instead of crashing on invalid UTF-8" do
      html =
        render_markdown(%{
          content: <<0xFF, 0xFE, "broken"::binary>>,
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ "Error rendering markdown"
    end

    test "renders an error notice for nil content instead of crashing" do
      html =
        render_markdown(%{
          content: nil,
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ "Error rendering markdown"
    end

    test "renders GFM tables" do
      html =
        render_markdown(%{
          content: "| A | B |\n| - | - |\n| 1 | 2 |",
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ "<table>"
      assert html =~ "<td>"
    end

    test "renders strikethrough" do
      html =
        render_markdown(%{
          content: "~~gone~~",
          prefix: "/clarity",
          lens: test_lens("test"),
          class: ""
        })

      assert html =~ "<del>"
    end
  end
end
