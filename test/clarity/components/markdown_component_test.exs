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
  end
end
