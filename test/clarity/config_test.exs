defmodule Clarity.ConfigTest do
  use ExUnit.Case, async: true

  alias Clarity.Config

  describe inspect(&Config.should_process_app?/1) do
    test "returns true for apps in include list" do
      Application.put_env(:clarity, :introspector_applications, [:clarity, :phoenix])

      assert Config.should_process_app?(:clarity)
      assert Config.should_process_app?(:phoenix)
    after
      Application.delete_env(:clarity, :introspector_applications)
    end

    test "returns false for apps not in include list" do
      Application.put_env(:clarity, :introspector_applications, [:clarity])

      refute Config.should_process_app?(:ecto)
      refute Config.should_process_app?(:phoenix)
    after
      Application.delete_env(:clarity, :introspector_applications)
    end

    test "excludes OTP apps by default when no config is set" do
      Application.delete_env(:clarity, :introspector_applications)

      refute Config.should_process_app?(:kernel)
      refute Config.should_process_app?(:stdlib)
    end

    test "excludes Elixir apps by default when no config is set" do
      Application.delete_env(:clarity, :introspector_applications)

      refute Config.should_process_app?(:elixir)
      refute Config.should_process_app?(:logger)
      refute Config.should_process_app?(:mix)
    end

    test "includes user apps by default when no config is set" do
      Application.delete_env(:clarity, :introspector_applications)

      assert Config.should_process_app?(:clarity)
    end
  end

  describe inspect(&Config.should_process_module?/1) do
    test "returns true for modules from apps in include list" do
      Application.put_env(:clarity, :introspector_applications, [:clarity])

      assert Config.should_process_module?(Clarity.Server)
      assert Config.should_process_module?(Config)
    after
      Application.delete_env(:clarity, :introspector_applications)
    end

    test "returns false for modules from apps not in include list" do
      Application.put_env(:clarity, :introspector_applications, [:phoenix])

      refute Config.should_process_module?(Clarity.Server)
      refute Config.should_process_module?(Config)
    after
      Application.delete_env(:clarity, :introspector_applications)
    end

    test "excludes OTP modules by default when no config is set" do
      Application.delete_env(:clarity, :introspector_applications)

      refute Config.should_process_module?(:gen_server)
      refute Config.should_process_module?(:supervisor)
    end

    test "excludes Elixir modules by default when no config is set" do
      Application.delete_env(:clarity, :introspector_applications)

      refute Config.should_process_module?(Enum)
      refute Config.should_process_module?(String)
      refute Config.should_process_module?(Logger)
    end

    test "includes user app modules by default when no config is set" do
      Application.delete_env(:clarity, :introspector_applications)

      assert Config.should_process_module?(Clarity.Server)
      assert Config.should_process_module?(Config)
    end

    test "returns false for modules that don't belong to any application" do
      Application.delete_env(:clarity, :introspector_applications)

      # Dynamically defined module won't belong to any application
      defmodule DynamicTestModule do
        @moduledoc false
      end

      refute Config.should_process_module?(DynamicTestModule)
    end
  end
end
