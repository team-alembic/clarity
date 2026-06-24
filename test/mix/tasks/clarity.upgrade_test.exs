defmodule Mix.Tasks.Clarity.UpgradeTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  test "configures the mdex_native syntax highlighter when upgrading across 0.6.0" do
    test_project()
    |> Igniter.compose_task("clarity.upgrade", ["0.5.1", "0.6.0"])
    |> assert_creates(
      "config/config.exs",
      "import Config\nconfig :mdex_native, syntax_highlighter: :lumis\n"
    )
  end

  test "leaves an existing syntax highlighter choice untouched" do
    [files: %{"config/config.exs" => "import Config\nconfig :mdex_native, syntax_highlighter: :syntect\n"}]
    |> test_project()
    |> Igniter.compose_task("clarity.upgrade", ["0.5.1", "0.6.0"])
    |> assert_content_equals(
      "config/config.exs",
      "import Config\n\nconfig :mdex_native, syntax_highlighter: :syntect\n"
    )
  end

  test "does nothing when the upgrade boundary is not crossed" do
    test_project()
    |> Igniter.compose_task("clarity.upgrade", ["0.6.0", "0.6.1"])
    |> assert_unchanged("config/config.exs")
  end
end
