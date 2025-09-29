defmodule Clarity.SourceLocationTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Clarity.SourceLocation
  alias Demo.Accounts.User

  describe "from_module_anno/2" do
    test "creates source location with module and annotation" do
      anno = :erl_anno.set_file(~c"lib/enum.ex", :erl_anno.new(42))

      source_location = SourceLocation.from_module_anno(Enum, anno)

      assert source_location.application == :elixir
      assert source_location.module == Enum
      assert source_location.anno == anno
    end

    test "handles unknown module" do
      anno = :erl_anno.set_file(~c"lib/test_module.ex", :erl_anno.new(42))

      # Create a fake module atom that likely doesn't exist
      # Using System.unique_integer to avoid conflicts, but we know this won't exist
      fake_module = :NonExistentModule999999999
      source_location = SourceLocation.from_module_anno(fake_module, anno)

      assert source_location.application == nil
      assert source_location.module == fake_module
      assert source_location.anno == anno
    end
  end

  describe "from_application_anno/2" do
    test "creates source location with application and annotation" do
      anno = :erl_anno.set_file(~c"lib/some_file.ex", :erl_anno.new(10))

      source_location = SourceLocation.from_application_anno(:my_app, anno)

      assert source_location.application == :my_app
      assert source_location.module == nil
      assert source_location.anno == anno
    end
  end

  describe "from_module/1" do
    test "creates source location from existing module" do
      source_location = SourceLocation.from_module(Enum)

      assert source_location.application == :elixir
      assert source_location.module == Enum
      assert SourceLocation.line(source_location) == 1
    end

    test "creates source location from test module" do
      source_location = SourceLocation.from_module(ExUnit.Case)

      assert source_location.application == :ex_unit
      assert source_location.module == ExUnit.Case
      assert SourceLocation.line(source_location) == 1
    end

    test "creates source location from non-existent module" do
      fake_module = :NonExistentModule888888888
      source_location = SourceLocation.from_module(fake_module)

      assert source_location.application == nil
      assert source_location.module == fake_module
      assert SourceLocation.file_path(source_location) == nil
      assert SourceLocation.line(source_location) == 1
    end
  end

  describe "from_path/2" do
    test "creates source location from application and path" do
      source_location = SourceLocation.from_path(:my_app, "/path/to/file.ex")

      assert source_location.application == :my_app
      assert source_location.module == nil
      assert SourceLocation.file_path(source_location) == "/path/to/file.ex"
      assert SourceLocation.line(source_location) == 1
    end

    test "handles empty path" do
      source_location = SourceLocation.from_path(:my_app, "")

      assert source_location.application == :my_app
      assert source_location.module == nil
      # Empty path gets expanded to current working directory
      assert source_location |> SourceLocation.file_path() |> String.ends_with?("clarity")
      assert SourceLocation.line(source_location) == 1
    end
  end

  describe "from_spark_entity/2" do
    test "creates source location from Ash attribute entity" do
      attribute = User |> Info.attributes() |> List.first()

      source_location = SourceLocation.from_spark_entity(User, attribute)

      assert source_location.anno
      assert source_location.module == User
      assert source_location.application == :clarity
    end
  end

  describe "file_path/1 and file_path/2" do
    test "extracts file path from annotation with charlist (default absolute)" do
      anno = :erl_anno.set_file(~c"lib/test.ex", :erl_anno.new(1))
      source_location = SourceLocation.from_application_anno(:elixir, anno)

      result = SourceLocation.file_path(source_location)
      assert String.ends_with?(result, "/lib/test.ex")
      assert Path.type(result) == :absolute
    end

    test "extracts file path from annotation with binary (default absolute)" do
      # Create annotation manually to test binary handling
      anno = :erl_anno.set_file("lib/test.ex", :erl_anno.new(1))
      source_location = SourceLocation.from_application_anno(:elixir, anno)

      result = SourceLocation.file_path(source_location)
      assert String.ends_with?(result, "/lib/test.ex")
      assert Path.type(result) == :absolute
    end

    test "returns nil for undefined file" do
      # No file set
      anno = :erl_anno.new(1)
      source_location = SourceLocation.from_application_anno(:elixir, anno)

      assert SourceLocation.file_path(source_location) == nil
      assert SourceLocation.file_path(source_location, :absolute) == nil
      assert SourceLocation.file_path(source_location, :cwd) == nil
    end

    test "file_path with :absolute option" do
      anno = :erl_anno.set_file(~c"lib/test.ex", :erl_anno.new(1))
      source_location = SourceLocation.from_application_anno(:elixir, anno)

      result = SourceLocation.file_path(source_location, :absolute)
      assert String.ends_with?(result, "/lib/test.ex")
      assert Path.type(result) == :absolute
    end

    test "file_path with :cwd option" do
      anno = :erl_anno.set_file(~c"lib/test.ex", :erl_anno.new(1))
      source_location = SourceLocation.from_application_anno(:elixir, anno)

      result = SourceLocation.file_path(source_location, :cwd)
      # Should be relative to current working directory
      refute String.starts_with?(result, "/")
      assert result == "lib/test.ex"
    end

    test "file_path with :cwd option and absolute input path" do
      # Test with an absolute path to ensure relative_to_cwd works correctly
      {:ok, cwd} = File.cwd()
      abs_path = Path.join(cwd, "lib/test.ex")

      anno = :erl_anno.set_file(String.to_charlist(abs_path), :erl_anno.new(1))
      source_location = SourceLocation.from_application_anno(:elixir, anno)

      result = SourceLocation.file_path(source_location, :cwd)
      assert result == "lib/test.ex"
    end

    test "file_path with :app option" do
      anno = :erl_anno.set_file(~c"lib/test.ex", :erl_anno.new(1))
      source_location = SourceLocation.from_application_anno(:elixir, anno)

      result = SourceLocation.file_path(source_location, :app)
      # Should be relative to the application directory
      assert result == "lib/test.ex"
    end

    test "backwards compatibility - default parameter works" do
      anno = :erl_anno.set_file(~c"lib/test.ex", :erl_anno.new(1))
      source_location = SourceLocation.from_application_anno(:elixir, anno)

      # Both should give the same result (absolute path)
      result1 = SourceLocation.file_path(source_location)
      result2 = SourceLocation.file_path(source_location, :absolute)

      assert result1 == result2
      assert Path.type(result1) == :absolute
    end
  end

  describe "line/1" do
    test "extracts line number from annotation" do
      anno = :erl_anno.set_file(~c"lib/test.ex", :erl_anno.new(42))
      source_location = SourceLocation.from_application_anno(:elixir, anno)

      assert SourceLocation.line(source_location) == 42
    end

    test "returns 1 for missing line information" do
      # Create annotation without line info (this might not be possible with :erl_anno,
      # but we test the defensive code)
      anno = :erl_anno.set_file(~c"lib/test.ex", :erl_anno.new(0))
      source_location = SourceLocation.from_application_anno(:elixir, anno)

      # Should default to 1 for invalid line numbers
      assert SourceLocation.line(source_location) == 1
    end
  end

  describe "column/1" do
    test "extracts column number when available" do
      anno = :erl_anno.set_file(~c"lib/test.ex", :erl_anno.new({42, 15}))

      source_location = SourceLocation.from_application_anno(:elixir, anno)

      assert SourceLocation.column(source_location) == 15
    end

    test "returns nil when column not available" do
      anno = :erl_anno.set_file(~c"lib/test.ex", :erl_anno.new(42))
      source_location = SourceLocation.from_application_anno(:elixir, anno)

      assert SourceLocation.column(source_location) == nil
    end
  end

  describe "integration tests" do
    test "round trip with all information" do
      # Create a comprehensive annotation
      anno = :erl_anno.set_file(~c"lib/enum.ex", :erl_anno.new({42, 15}))

      source_location = SourceLocation.from_module_anno(Enum, anno)

      # Verify all information is preserved and accessible
      assert source_location.application == :elixir
      assert source_location.module == Enum
      assert source_location |> SourceLocation.file_path() |> String.ends_with?("/lib/enum.ex")
      assert SourceLocation.line(source_location) == 42
      assert SourceLocation.column(source_location) == 15
    end

    test "works with real module" do
      # Test with an actual existing module
      source_location = SourceLocation.from_module(Enum)

      assert source_location.application == :elixir
      assert source_location.module == Enum
      assert SourceLocation.line(source_location) == 1

      # File path might be available depending on the environment
      file_path = SourceLocation.file_path(source_location)
      assert file_path == nil or is_binary(file_path)
    end

    test "works with clarity module" do
      # Test with a module from our own application
      source_location = SourceLocation.from_module(SourceLocation)

      assert source_location.application == :clarity
      assert source_location.module == SourceLocation
      assert SourceLocation.line(source_location) == 1

      # Should have a file path since it's our own code
      file_path = SourceLocation.file_path(source_location)
      assert is_binary(file_path)
      assert String.ends_with?(file_path, "source_location.ex")
    end
  end
end
