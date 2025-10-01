defmodule Clarity.Introspector.Ash.Domain.OverviewContentTest do
  use ExUnit.Case, async: true

  alias Demo.Accounts.Domain
  alias Demo.Accounts.User

  if Code.ensure_loaded?(Ash) do
    alias Clarity.Introspector.Ash.Domain.OverviewContent
    alias Clarity.Vertex.Content

    defmodule TestDomainEmpty do
      @moduledoc """
      Test domain with no resources.
      """

      use Ash.Domain, validate_config_inclusion?: false
    end

    describe "generate_content/1" do
      test "returns a Content struct with correct id and name" do
        content = OverviewContent.generate_content(Domain)

        assert %Content{} = content
        assert content.id == "#{inspect(Domain)}_overview"
        assert content.name == "Domain Overview"
        assert match?({:markdown, _function}, content.content)
      end

      test "generates markdown content for domain with resources" do
        content = OverviewContent.generate_content(Domain)
        {:markdown, markdown_fn} = content.content
        markdown = IO.iodata_to_binary(markdown_fn.())

        # Check domain information section
        assert markdown =~ "## Domain Information"
        assert markdown =~ "| **Domain** | [#{inspect(Domain)}](vertex://domain:#{inspect(Domain)}) |"
        assert markdown =~ "| **Description** | The Accounts domain. This handles user management and authentication. |"

        # Check resources section
        assert markdown =~ "## Resources"
        assert markdown =~ "| Resource | Description |"
        assert markdown =~ "[#{inspect(User)}](vertex://resource:#{inspect(User)})"
      end

      test "handles domain with no resources" do
        content = OverviewContent.generate_content(TestDomainEmpty)
        {:markdown, markdown_fn} = content.content
        markdown = IO.iodata_to_binary(markdown_fn.())

        # Check domain information section
        assert markdown =~ "## Domain Information"
        assert markdown =~ "[#{inspect(TestDomainEmpty)}](vertex://domain:#{inspect(TestDomainEmpty)})"

        # Check empty resources section
        assert markdown =~ "## Resources"
        assert markdown =~ "This domain has no resources defined."
      end

      test "creates proper vertex:// links for navigation" do
        content = OverviewContent.generate_content(Domain)
        {:markdown, markdown_fn} = content.content
        markdown = IO.iodata_to_binary(markdown_fn.())

        # Verify vertex:// link format
        assert markdown =~ "vertex://domain:#{inspect(Domain)}"
        assert markdown =~ "vertex://resource:#{inspect(User)}"
      end

      test "extracts only first paragraph from moduledoc" do
        content = OverviewContent.generate_content(Domain)
        {:markdown, markdown_fn} = content.content
        markdown = IO.iodata_to_binary(markdown_fn.())

        # Should only include first paragraph (first two lines before empty line)
        assert markdown =~ "The Accounts domain. This handles user management and authentication."
        # Should not include subsequent paragraphs
        refute markdown =~ "This is a second paragraph that should be ignored"
        refute markdown =~ "And this is a third paragraph"
      end
    end
  end
end
