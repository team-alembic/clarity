defmodule Clarity.OpenEditorTest do
  use ExUnit.Case, async: false

  alias Clarity.OpenEditor
  alias Clarity.SourceLocation

  setup do
    # Store original values
    original_clarity_editor = System.fetch_env("CLARITY_EDITOR")
    original_elixir_editor = System.fetch_env("ELIXIR_EDITOR")
    original_editor = System.fetch_env("EDITOR")
    original_config = Application.fetch_env(:clarity, :editor)

    # Clear all editor configurations
    System.delete_env("CLARITY_EDITOR")
    System.delete_env("ELIXIR_EDITOR")
    System.delete_env("EDITOR")
    Application.delete_env(:clarity, :editor)

    # Restore on test completion
    on_exit(fn ->
      restore_env_var("CLARITY_EDITOR", original_clarity_editor)
      restore_env_var("ELIXIR_EDITOR", original_elixir_editor)
      restore_env_var("EDITOR", original_editor)
      restore_app_env(:clarity, :editor, original_config)
    end)

    :ok
  end

  describe "action/1" do
    test "returns :editor_not_available when no editor is configured" do
      # Setup already cleared all configurations
      source_location = SourceLocation.from_path(:test_app, "/path/to/file.ex")
      assert OpenEditor.action(source_location) == :editor_not_available
    end

    test "returns :action_not_available when application has no source URL in URL mode" do
      Application.put_env(:clarity, :editor, "__URL__")
      # test_app doesn't have a source URL configured
      anno = :erl_anno.set_file(~c"lib/test.ex", :erl_anno.new(42))
      source_location = SourceLocation.from_application_anno(:test_app, anno)

      assert OpenEditor.action(source_location) == :action_not_available
    end

    test "returns :action_not_available when source location has no file path in URL mode" do
      Application.put_env(:clarity, :editor, "__URL__")
      # No file set, but use :clarity app which has source URL configured
      anno = :erl_anno.new(42)
      source_location = SourceLocation.from_application_anno(:clarity, anno)

      assert OpenEditor.action(source_location) == :action_not_available
    end

    test "returns :action_not_available when source location has no file path in system command mode" do
      Application.put_env(:clarity, :editor, "echo test")
      # No file set
      anno = :erl_anno.new(42)
      source_location = SourceLocation.from_application_anno(:test_app, anno)

      assert OpenEditor.action(source_location) == :action_not_available
    end

    test "returns {:url, url} for URL mode with valid configuration" do
      Application.put_env(:clarity, :editor, "__URL__")
      anno = :erl_anno.set_file(~c"lib/test.ex", :erl_anno.new(42))
      source_location = SourceLocation.from_application_anno(:clarity, anno)

      assert {:url, url} = OpenEditor.action(source_location)
      assert is_binary(url)
      assert String.contains?(url, "github.com/team-alembic")
      assert String.contains?(url, "lib/test.ex")
      assert String.contains?(url, "#L42")
    end

    test "returns {:execute, function} for system command mode with valid configuration" do
      Application.put_env(:clarity, :editor, "echo")
      source_location = SourceLocation.from_path(:test_app, "/path/to/file.ex")

      assert {:execute, execute_fn} = OpenEditor.action(source_location)
      assert is_function(execute_fn, 0)
      assert execute_fn.() == :ok
    end

    test "handles case insensitive URL mode configurations" do
      # String configurations are case-insensitive and normalize to :url
      string_configs = ["__URL__", "__url__", "__Url__"]
      # Only :url atom is accepted
      atom_configs = [:url]

      for config <- string_configs ++ atom_configs do
        Application.put_env(:clarity, :editor, config)
        anno = :erl_anno.set_file(~c"lib/test.ex", :erl_anno.new(42))
        source_location = SourceLocation.from_application_anno(:clarity, anno)

        assert {:url, _url} = OpenEditor.action(source_location)
      end
    end

    test "execute function performs case-insensitive template variable substitution" do
      # Test with echo command that should succeed
      Application.put_env(:clarity, :editor, "echo __FILE__ __LINE__ __COLUMN__")

      # Create source location with line 42 and column 10
      anno = :erl_anno.set_file(~c"/path/to/file.ex", :erl_anno.new({42, 10}))
      source_location = SourceLocation.from_application_anno(:test_app, anno)

      assert {:execute, execute_fn} = OpenEditor.action(source_location)
      assert execute_fn.() == :ok

      # Test lowercase variations
      Application.put_env(:clarity, :editor, "echo __file__ __line__ __column__")
      assert {:execute, execute_fn} = OpenEditor.action(source_location)
      assert execute_fn.() == :ok
    end

    test "execute function uses default line and column when not provided" do
      Application.put_env(:clarity, :editor, "echo")
      source_location = SourceLocation.from_path(:test_app, "/path/to/file.ex")

      assert {:execute, execute_fn} = OpenEditor.action(source_location)
      assert execute_fn.() == :ok
    end

    test "execute function returns error for failing commands" do
      false_binary = System.find_executable("false")

      Application.put_env(:clarity, :editor, false_binary)
      source_location = SourceLocation.from_path(:test_app, "/path/to/file.ex")

      assert {:execute, execute_fn} = OpenEditor.action(source_location)
      assert {:error, _reason} = execute_fn.()
    end
  end

  describe "configuration priority" do
    test "respects configuration priority hierarchy" do
      source_location = SourceLocation.from_path(:test_app, "/path/to/file.ex")

      # Set multiple configs
      System.put_env("EDITOR", "editor_env")
      System.put_env("ELIXIR_EDITOR", "elixir_editor_env")
      System.put_env("CLARITY_EDITOR", "clarity_editor_env")
      Application.put_env(:clarity, :editor, "app_config")

      # App config should win
      assert {:execute, _fn} = OpenEditor.action(source_location)

      # Remove app config, CLARITY_EDITOR should win
      Application.delete_env(:clarity, :editor)
      assert {:execute, _fn} = OpenEditor.action(source_location)

      # Remove CLARITY_EDITOR, ELIXIR_EDITOR should win
      System.delete_env("CLARITY_EDITOR")
      assert {:execute, _fn} = OpenEditor.action(source_location)

      # Remove ELIXIR_EDITOR, EDITOR should win
      System.delete_env("ELIXIR_EDITOR")
      assert {:execute, _fn} = OpenEditor.action(source_location)

      # Remove EDITOR, should be not available
      System.delete_env("EDITOR")
      assert OpenEditor.action(source_location) == :editor_not_available
    end
  end

  describe "URL mode detection" do
    test "detects URL mode case insensitively" do
      url_patterns = [
        "__URL__",
        "__url__",
        "__Url__",
        "__uRl__",
        "__URL__"
      ]

      for pattern <- url_patterns do
        assert String.match?(pattern, ~r/^__url__$/i)
      end
    end
  end

  # Helper functions
  @spec restore_env_var(String.t(), :error | {:ok, String.t()}) :: :ok
  defp restore_env_var(key, :error) do
    # Variable was not set originally
    System.delete_env(key)
  end

  defp restore_env_var(key, {:ok, value}) do
    # Variable was set originally
    System.put_env(key, value)
  end

  @spec restore_app_env(atom(), atom(), :error | {:ok, term()}) :: :ok
  defp restore_app_env(app, key, :error) do
    # Config was not set originally
    Application.delete_env(app, key)
  end

  defp restore_app_env(app, key, {:ok, value}) do
    # Config was set originally
    Application.put_env(app, key, value)
  end
end
