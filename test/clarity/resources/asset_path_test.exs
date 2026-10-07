defmodule Clarity.Resources.AssetPathTest do
  use ExUnit.Case, async: true

  alias Clarity.Resources.AssetPath

  @moduletag :tmp_dir

  test "uses the built asset in priv when no dev assets path is set" do
    assert AssetPath.pick(nil, "app.js", "/priv/static/assets/app.js") == "/priv/static/assets/app.js"
  end

  test "uses the dev build when the dev assets path has one", %{tmp_dir: dir} do
    File.write!(Path.join(dir, "app.js"), "// dev build")

    assert AssetPath.pick(dir, "app.js", "/priv/static/assets/app.js") == Path.join(dir, "app.js")
  end

  test "falls back to priv until the dev build exists", %{tmp_dir: dir} do
    assert AssetPath.pick(dir, "app.css", "/priv/static/assets/app.css") == "/priv/static/assets/app.css"
  end
end
