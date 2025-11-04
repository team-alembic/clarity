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

  describe "markdown/1" do
    test "renders basic markdown without vertex links" do
      assigns = %{
        content: "# Hello World\n\nThis is a test.",
        prefix: "/clarity",
        lens: test_lens("test"),
        class: "test-class"
      }

      html =
        rendered_to_string(~H"""
        <.markdown content={@content} prefix={@prefix} lens={@lens} class={@class} />
        """)

      assert html =~ "Hello World"
      assert html =~ "This is a test."
      assert html =~ "prose dark:prose-invert test-class"
    end

    test "transforms vertex:// links to clarity paths" do
      assigns = %{
        content: "Check out [MyApp.User](vertex://resource:MyApp.User) resource.",
        prefix: "/clarity",
        lens: test_lens("debug"),
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <.markdown content={@content} prefix={@prefix} lens={@lens} class={@class} />
        """)

      assert html =~ ~s[href="/clarity/debug/resource:MyApp.User"]
      assert html =~ ~s[data-phx-link="patch"]
      assert html =~ ~s[data-phx-link-state="push"]
      assert html =~ ">MyApp.User</a>"
    end

    test "handles multiple vertex:// links" do
      content = """
      Resource: [MyApp.User](vertex://resource:MyApp.User)
      Domain: [MyApp.Domain](vertex://domain:MyApp.Domain)
      """

      assigns = %{
        content: content,
        prefix: "/clarity",
        lens: test_lens("overview"),
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <.markdown content={@content} prefix={@prefix} lens={@lens} class={@class} />
        """)

      assert html =~ ~s[href="/clarity/overview/resource:MyApp.User"]
      assert html =~ ~s[href="/clarity/overview/domain:MyApp.Domain"]
      assert html =~ ~s[data-phx-link="patch"]
      assert html =~ ~s[data-phx-link-state="push"]
    end

    test "leaves non-vertex links unchanged" do
      assigns = %{
        content: "Visit [Google](https://google.com) for search.",
        prefix: "/clarity",
        lens: test_lens("test"),
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <.markdown content={@content} prefix={@prefix} lens={@lens} class={@class} />
        """)

      assert html =~ ~s[href="https://google.com"]
      refute html =~ ~s[data-phx-link="patch"]
      refute html =~ ~s[data-phx-link-state="push"]
    end

    test "handles iodata content" do
      assigns = %{
        content: ["# Title\n\n", "Link: [Resource](vertex://resource:Test)"],
        prefix: "/clarity",
        lens: test_lens("test"),
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <.markdown content={@content} prefix={@prefix} lens={@lens} class={@class} />
        """)

      assert html =~ "Title"
      assert html =~ ~s[href="/clarity/test/resource:Test"]
      assert html =~ ~s[data-phx-link="patch"]
      assert html =~ ~s[data-phx-link-state="push"]
    end

    test "highlights Elixir code blocks" do
      content = """
      Here's some Elixir code:

      ```elixir
      defmodule Test do
        def hello, do: :world
      end
      ```
      """

      assigns = %{
        content: content,
        prefix: "/clarity",
        lens: test_lens("test"),
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <.markdown content={@content} prefix={@prefix} lens={@lens} class={@class} />
        """)

      assert html =~ ~s[<pre class="highlight">]
      assert html =~ "defmodule"
      assert html =~ "Test"
      assert html =~ "hello"
    end

    test "does not highlight code blocks without language" do
      content = """
      Plain code block:

      ```
      some plain code
      without highlighting
      ```
      """

      assigns = %{
        content: content,
        prefix: "/clarity",
        lens: test_lens("test"),
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <.markdown content={@content} prefix={@prefix} lens={@lens} class={@class} />
        """)

      assert html =~ "<pre>"
      assert html =~ "<code>"
      assert html =~ "some plain code"
      refute html =~ ~s[class="highlight"]
    end

    test "does not highlight code blocks with unsupported language" do
      content = """
      Python code block:

      ```python
      def hello():
          return "world"
      ```
      """

      assigns = %{
        content: content,
        prefix: "/clarity",
        lens: test_lens("test"),
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <.markdown content={@content} prefix={@prefix} lens={@lens} class={@class} />
        """)

      assert html =~ "<pre>"
      assert html =~ "def hello"
      refute html =~ "makeup"
    end

    test "highlights Erlang code blocks" do
      content = """
      Here's some Erlang code:

      ```erlang
      -module(test).
      -export([hello/0]).
      hello() -> world.
      ```
      """

      assigns = %{
        content: content,
        prefix: "/clarity",
        lens: test_lens("test"),
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <.markdown content={@content} prefix={@prefix} lens={@lens} class={@class} />
        """)

      assert html =~ ~s[<pre class="highlight">]
      assert html =~ "module"
      assert html =~ "test"
    end

    test "handles both highlighting and vertex links together" do
      content = """
      Check the [MyApp.User](vertex://resource:MyApp.User) resource:

      ```elixir
      defmodule MyApp.User do
        use Ash.Resource
      end
      ```
      """

      assigns = %{
        content: content,
        prefix: "/clarity",
        lens: test_lens("test"),
        class: ""
      }

      html =
        rendered_to_string(~H"""
        <.markdown content={@content} prefix={@prefix} lens={@lens} class={@class} />
        """)

      assert html =~ ~s[href="/clarity/test/resource:MyApp.User"]
      assert html =~ ~s[data-phx-link="patch"]
      assert html =~ ~s[<pre class="highlight">]
      assert html =~ "defmodule"
      assert html =~ "MyApp.User"
    end
  end
end
