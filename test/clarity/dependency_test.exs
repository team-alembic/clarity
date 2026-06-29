defmodule Clarity.DependencyTest do
  use ExUnit.Case, async: true

  alias Clarity.Dependency

  describe "summarise/1" do
    test "picks the highest version as latest" do
      summary = Dependency.summarise(%{versions: ["1.0.0", "1.1.0", "2.0.0"]})
      assert summary == %{latest: "2.0.0", retired: []}
    end

    test "excludes retired versions (by index) from latest and lists them" do
      summary = Dependency.summarise(%{versions: ["1.0.0", "1.1.0", "2.0.0"], retired: [2]})
      assert summary == %{latest: "1.1.0", retired: ["2.0.0"]}
    end

    test "excludes pre-releases from latest" do
      summary = Dependency.summarise(%{versions: ["1.0.0", "2.0.0-rc1"]})
      assert summary.latest == "1.0.0"
    end

    test "latest is nil when there is no stable version" do
      summary = Dependency.summarise(%{versions: ["1.0.0-rc1"]})
      assert summary.latest == nil
    end
  end

  describe "outdated?/2" do
    test "true when installed is behind latest" do
      assert Dependency.outdated?("1.0.0", "2.0.0")
    end

    test "false when up to date or ahead" do
      refute Dependency.outdated?("2.0.0", "2.0.0")
      refute Dependency.outdated?("2.1.0", "2.0.0")
    end

    test "false when latest is unknown" do
      refute Dependency.outdated?("1.0.0", nil)
    end

    test "false when versions are unparseable" do
      refute Dependency.outdated?("weird", "2.0.0")
    end
  end
end
