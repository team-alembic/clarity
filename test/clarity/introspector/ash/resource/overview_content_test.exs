defmodule Clarity.Introspector.Ash.Resource.OverviewContentTest do
  use ExUnit.Case, async: true

  if Code.ensure_loaded?(Ash) do
    alias Clarity.Introspector.Ash.Resource.OverviewContent
    alias Clarity.Vertex.Content

    defmodule TestResource do
      @moduledoc """
      Test resource for overview content generation.
      """

      use Ash.Resource,
        domain: TestDomain,
        validate_domain_inclusion?: false

      alias Clarity.Introspector.Ash.Resource.OverviewContentTest.TestDomain

      attributes do
        uuid_primary_key :id

        attribute :name, :string do
          allow_nil? false
          public? true
          description "The name of the resource"
        end

        attribute :email, :string do
          allow_nil? true
          public? true
          description "Email address"
        end

        attribute :internal_field, :string do
          allow_nil? true
          public? false
          description "Internal field not exposed publicly"
        end
      end

      relationships do
        belongs_to :owner, Clarity.Introspector.Ash.Resource.OverviewContentTest.TestOwner do
          description "The owner of this resource"
          domain TestDomain
        end

        has_many :items, Clarity.Introspector.Ash.Resource.OverviewContentTest.TestItem do
          description "Items belonging to this resource"
          domain TestDomain
        end
      end

      actions do
        defaults [:read, :destroy]

        create :create do
          description "Creates a new test resource"
          primary? true
        end

        update :update do
          description "Updates an existing test resource"
          primary? true
        end

        read :by_name do
          description "Find resource by name"
          primary? false
        end
      end

      # Note: Aggregates removed due to test limitations with Simple data layer

      calculations do
        calculate :display_name, :string, expr(name <> " (" <> email <> ")") do
          description "Display name with email"
        end

        calculate :item_summary, :string, {MyApp.Calculations.ItemSummary, []} do
          description "Summary of items"
        end
      end
    end

    defmodule TestOwner do
      @moduledoc false
      use Ash.Resource,
        domain: TestDomain,
        validate_domain_inclusion?: false

      attributes do
        uuid_primary_key :id
        attribute :name, :string
      end
    end

    defmodule TestItem do
      @moduledoc false
      use Ash.Resource,
        domain: TestDomain,
        validate_domain_inclusion?: false

      attributes do
        uuid_primary_key :id
        attribute :name, :string
        attribute :value, :decimal
      end

      relationships do
        belongs_to :test_resource, Clarity.Introspector.Ash.Resource.OverviewContentTest.TestResource do
          domain Clarity.Introspector.Ash.Resource.OverviewContentTest.TestDomain
        end
      end
    end

    defmodule TestDomain do
      @moduledoc false
      use Ash.Domain, validate_config_inclusion?: false

      resources do
        resource TestResource
        resource TestOwner
        resource TestItem
      end
    end

    describe "generate_content/1" do
      test "creates a Content vertex with correct structure" do
        content = OverviewContent.generate_content(TestResource)

        assert %Content{} = content
        assert content.id == "#{inspect(TestResource)}_overview"
        assert content.name == "Resource Overview"
        assert match?({:markdown, fun} when is_function(fun), content.content)
      end

      test "generates markdown when content function is called" do
        content = OverviewContent.generate_content(TestResource)
        {:markdown, markdown_fn} = content.content

        markdown = IO.iodata_to_binary(markdown_fn.())

        # Check main sections are present (title is now shown in page, not markdown)
        assert markdown =~ "## Resource Information"
        assert markdown =~ "## Attributes"
        assert markdown =~ "## Relationships"
        assert markdown =~ "## Actions"
        assert markdown =~ "## Calculations"
      end
    end

    describe "resource information section" do
      test "includes basic resource information" do
        content = OverviewContent.generate_content(TestResource)
        {:markdown, markdown_fn} = content.content
        markdown = IO.iodata_to_binary(markdown_fn.())

        assert markdown =~ "| **Resource** | [#{inspect(TestResource)}](vertex://resource:#{inspect(TestResource)}) |"
        assert markdown =~ "| **Domain** | [TestDomain](vertex://domain:TestDomain) |"
      end
    end

    describe "attributes section" do
      test "includes all attributes with proper formatting" do
        content = OverviewContent.generate_content(TestResource)
        {:markdown, markdown_fn} = content.content
        markdown = IO.iodata_to_binary(markdown_fn.())

        # Check table headers
        assert markdown =~ "| Name | Type | Description | Primary Key | Allow Nil | Public |"

        # Check each attribute row with links
        assert markdown =~ "[id](vertex://attribute:#{inspect(TestResource)}:id)"
        assert markdown =~ "[name](vertex://attribute:#{inspect(TestResource)}:name)"
        assert markdown =~ "[email](vertex://attribute:#{inspect(TestResource)}:email)"
        assert markdown =~ "[internal_field](vertex://attribute:#{inspect(TestResource)}:internal_field)"

        # Check attribute properties
        assert markdown =~ "The name of the resource"
        assert markdown =~ "Email address"
        assert markdown =~ "Internal field not exposed publicly"

        # Check boolean values
        # primary key
        assert markdown =~ "| true |"
        # allow_nil for name
        assert markdown =~ "| false |"
        # allow_nil for email
        assert markdown =~ "| true |"
        # public for name
        assert markdown =~ "| true |"
        # public for internal_field
        assert markdown =~ "| false |"
      end

      test "handles resources with no attributes" do
        defmodule EmptyResource do
          @moduledoc false
          use Ash.Resource,
            domain: nil,
            validate_domain_inclusion?: false

          resource do
            require_primary_key? false
          end
        end

        content = OverviewContent.generate_content(EmptyResource)
        {:markdown, markdown_fn} = content.content
        markdown = IO.iodata_to_binary(markdown_fn.())

        refute markdown =~ "## Attributes"
      end
    end

    describe "relationships section" do
      test "includes all relationships with proper formatting" do
        content = OverviewContent.generate_content(TestResource)
        {:markdown, markdown_fn} = content.content
        markdown = IO.iodata_to_binary(markdown_fn.())

        # Check table headers
        assert markdown =~ "| Name | Type | Destination | Description |"

        # Check relationship rows with links
        assert markdown =~ "[owner](vertex://relationship:#{inspect(TestResource)}:owner)"
        assert markdown =~ "[items](vertex://relationship:#{inspect(TestResource)}:items)"

        # Check relationship properties
        assert markdown =~ "| `belongs_to` |"
        assert markdown =~ "| `has_many` |"

        assert markdown =~
                 "[Clarity.Introspector.Ash.Resource.OverviewContentTest.TestOwner](vertex://resource:Clarity.Introspector.Ash.Resource.OverviewContentTest.TestOwner)"

        assert markdown =~
                 "[Clarity.Introspector.Ash.Resource.OverviewContentTest.TestItem](vertex://resource:Clarity.Introspector.Ash.Resource.OverviewContentTest.TestItem)"

        assert markdown =~ "The owner of this resource"
        assert markdown =~ "Items belonging to this resource"
      end
    end

    describe "actions section" do
      test "groups actions by type and includes details" do
        content = OverviewContent.generate_content(TestResource)
        {:markdown, markdown_fn} = content.content
        markdown = IO.iodata_to_binary(markdown_fn.())

        # Check section headers
        assert markdown =~ "## Actions"
        assert markdown =~ "### Create Actions"
        assert markdown =~ "### Read Actions"
        assert markdown =~ "### Update Actions"
        assert markdown =~ "### Destroy Actions"

        # Check action details
        assert markdown =~
                 "| [create](vertex://action:#{inspect(TestResource)}:create) | Creates a new test resource | true |"

        assert markdown =~
                 "| [update](vertex://action:#{inspect(TestResource)}:update) | Updates an existing test resource | true |"

        assert markdown =~
                 "| [by_name](vertex://action:#{inspect(TestResource)}:by_name) | Find resource by name | false |"

        assert markdown =~ "| [read](vertex://action:#{inspect(TestResource)}:read) |"
        assert markdown =~ "| [destroy](vertex://action:#{inspect(TestResource)}:destroy) |"
      end
    end

    describe "aggregates section" do
      test "handles resources with no aggregates" do
        content = OverviewContent.generate_content(TestResource)
        {:markdown, markdown_fn} = content.content
        markdown = IO.iodata_to_binary(markdown_fn.())

        # Should not have aggregates section since TestResource has no aggregates
        refute markdown =~ "## Aggregates"
      end
    end

    describe "calculations section" do
      test "includes all calculations with proper formatting" do
        content = OverviewContent.generate_content(TestResource)
        {:markdown, markdown_fn} = content.content
        markdown = IO.iodata_to_binary(markdown_fn.())

        # Check table headers
        assert markdown =~ "| Name | Type | Description |"

        # Check calculation rows
        assert markdown =~
                 "| [display_name](vertex://calculation:#{inspect(TestResource)}:display_name) | [String](vertex://type:Ash.Type.String) | Display name with email |"

        assert markdown =~
                 "| [item_summary](vertex://calculation:#{inspect(TestResource)}:item_summary) | [String](vertex://type:Ash.Type.String) | Summary of items |"
      end
    end

    describe "type formatting" do
      test "formats array types correctly" do
        defmodule ArrayTypeResource do
          @moduledoc false
          use Ash.Resource,
            domain: nil,
            validate_domain_inclusion?: false

          attributes do
            uuid_primary_key :id
            attribute :tags, {:array, :string}
            attribute :numbers, {:array, :integer}
          end
        end

        content = OverviewContent.generate_content(ArrayTypeResource)
        {:markdown, markdown_fn} = content.content
        markdown = IO.iodata_to_binary(markdown_fn.())

        assert markdown =~ "| list of [String](vertex://type:Ash.Type.String) |"
        assert markdown =~ "| list of [Integer](vertex://type:Ash.Type.Integer) |"
      end

      test "strips common prefixes from type names" do
        defmodule TypeTestResource do
          @moduledoc false
          use Ash.Resource,
            domain: nil,
            validate_domain_inclusion?: false

          attributes do
            uuid_primary_key :id
            attribute :ash_type_field, Ash.Type.String
            attribute :regular_field, :string
          end
        end

        content = OverviewContent.generate_content(TypeTestResource)
        {:markdown, markdown_fn} = content.content
        markdown = IO.iodata_to_binary(markdown_fn.())

        assert markdown =~ "| [String](vertex://type:Ash.Type.String) |"
      end
    end

    test "cleans multiline descriptions for table cells" do
      defmodule MultilineDescriptionResource do
        @moduledoc false
        use Ash.Resource,
          domain: nil,
          validate_domain_inclusion?: false

        attributes do
          uuid_primary_key :id

          attribute :name, :string do
            description "This is a multiline\ndescription that should\nbe cleaned up"
          end
        end

        actions do
          defaults [:read, :create, :update, :destroy]

          create :special_create do
            description "  A special create action  \n  with whitespace and newlines  "
          end
        end

        relationships do
          belongs_to :owner, Clarity.Introspector.Ash.Resource.OverviewContentTest.TestOwner do
            description "\n\n  Trimmed description  \n\n"
            domain nil
          end
        end

        calculations do
          calculate :display_name, :string, expr(name) do
            description "Calculation with\nnewlines\nand spaces  "
          end
        end
      end

      content = OverviewContent.generate_content(MultilineDescriptionResource)
      {:markdown, markdown_fn} = content.content

      markdown = IO.iodata_to_binary(markdown_fn.())

      # Check that descriptions are cleaned up (no newlines, trimmed)
      assert markdown =~ "| This is a multiline description that should be cleaned up |"
      assert markdown =~ "| A special create action with whitespace and newlines |"
      assert markdown =~ "| Trimmed description |"
      assert markdown =~ "| Calculation with newlines and spaces |"

      # Make sure there are no actual newlines within table cells
      refute markdown =~ "multiline\ndescription"
      refute markdown =~ "  \n  "
      refute markdown =~ "\n\n  Trimmed"
    end
  else
    # Ash not available, create placeholder tests
    test "skips tests when Ash is not available" do
      assert true
    end
  end
end
