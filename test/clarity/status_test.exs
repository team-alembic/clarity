defmodule Clarity.StatusTest do
  use ExUnit.Case, async: true

  alias Clarity.Status

  doctest Status

  describe inspect(&Status.severities/0) do
    test "ordered least to most severe" do
      assert Status.severities() == [:info, :warning, :error]
    end
  end

  describe inspect(&Status.rank/1) do
    test "orders info < warning < error" do
      assert Status.rank(:info) < Status.rank(:warning)
      assert Status.rank(:warning) < Status.rank(:error)
    end
  end

  describe inspect(&Status.max_severity/2) do
    test "returns the more severe of the two" do
      assert Status.max_severity(:info, :error) == :error
      assert Status.max_severity(:warning, :info) == :warning
      assert Status.max_severity(:warning, :warning) == :warning
    end
  end

  describe "struct" do
    test "enforces all keys" do
      assert_raise ArgumentError, fn -> struct!(Status, severity: :info, class: :security) end
    end

    test "builds with all keys" do
      status = %Status{severity: :error, class: :security, message: "boom", source: __MODULE__}

      assert status.severity == :error
      assert status.class == :security
      assert status.source == __MODULE__
    end
  end
end
