defmodule Clarity.ConfigTest do
  use ExUnit.Case, async: false

  alias Clarity.Config

  setup do
    original_config = Application.fetch_env(:clarity, :introspector_applications)
    Application.delete_env(:clarity, :introspector_applications)

    on_exit(fn ->
      case original_config do
        {:ok, value} ->
          Application.put_env(:clarity, :introspector_applications, value)

        :error ->
          Application.delete_env(:clarity, :introspector_applications)
      end
    end)

    :ok
  end

  describe inspect(&Config.should_process_app?/1) do
    test "returns true for apps in include list" do
      Application.put_env(:clarity, :introspector_applications, [:clarity, :phoenix])

      assert Config.should_process_app?(:clarity)
      assert Config.should_process_app?(:phoenix)
    end

    test "returns false for apps not in include list" do
      Application.put_env(:clarity, :introspector_applications, [:clarity])

      refute Config.should_process_app?(:ecto)
      refute Config.should_process_app?(:phoenix)
    end

    test "excludes OTP apps by default when no config is set" do
      refute Config.should_process_app?(:kernel)
      refute Config.should_process_app?(:stdlib)
    end

    test "excludes Elixir apps by default when no config is set" do
      refute Config.should_process_app?(:elixir)
      refute Config.should_process_app?(:logger)
      refute Config.should_process_app?(:mix)
    end

    test "includes user apps by default when no config is set" do
      assert Config.should_process_app?(:clarity)
    end
  end

  describe inspect(&Config.should_process_module?/1) do
    test "returns true for modules from apps in include list" do
      Application.put_env(:clarity, :introspector_applications, [:clarity])

      assert Config.should_process_module?(Clarity.Server)
      assert Config.should_process_module?(Config)
    end

    test "returns false for modules from apps not in include list" do
      Application.put_env(:clarity, :introspector_applications, [:phoenix])

      refute Config.should_process_module?(Clarity.Server)
      refute Config.should_process_module?(Config)
    end

    test "excludes OTP modules by default when no config is set" do
      refute Config.should_process_module?(:gen_server)
      refute Config.should_process_module?(:supervisor)
    end

    test "excludes Elixir modules by default when no config is set" do
      refute Config.should_process_module?(Enum)
      refute Config.should_process_module?(String)
      refute Config.should_process_module?(Logger)
    end

    test "includes user app modules by default when no config is set" do
      assert Config.should_process_module?(Clarity.Server)
      assert Config.should_process_module?(Config)
    end

    defmodule DynamicTestModule do
      @moduledoc false
    end

    test "returns false for modules that don't belong to any application" do
      refute Config.should_process_module?(DynamicTestModule)
    end
  end

  describe inspect(&Config.list_status_providers/0) do
    setup do
      on_exit(fn -> Application.delete_env(:clarity, :clarity_status_providers) end)
    end

    defmodule DummyStatusProvider do
      @moduledoc false
    end

    test "returns providers registered under :clarity_status_providers" do
      Application.put_env(:clarity, :clarity_status_providers, [DummyStatusProvider])

      assert DummyStatusProvider in Config.list_status_providers()
    end

    test "defaults to empty when unset" do
      Application.delete_env(:clarity, :clarity_status_providers)

      assert Config.list_status_providers() == []
    end
  end

  describe inspect(&Config.list_reports/0) do
    setup do
      on_exit(fn -> Application.delete_env(:clarity, :clarity_reports) end)
    end

    defmodule DummyReport do
      @moduledoc false
    end

    test "returns reports registered under :clarity_reports" do
      Application.put_env(:clarity, :clarity_reports, [DummyReport])

      assert DummyReport in Config.list_reports()
    end

    test "defaults to empty when unset" do
      Application.delete_env(:clarity, :clarity_reports)

      assert Config.list_reports() == []
    end
  end
end
