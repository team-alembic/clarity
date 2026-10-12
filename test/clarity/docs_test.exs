defmodule Clarity.DocsTest do
  use ExUnit.Case, async: true

  alias Clarity.Docs

  describe inspect(&Docs.fetch/1) do
    test "returns what Code.fetch_docs/1 does" do
      assert Docs.fetch(Clarity.Graph) == Code.fetch_docs(Clarity.Graph)
      assert Docs.fetch(Enum) == Code.fetch_docs(Enum)
    end

    test "keeps a loaded module's docs" do
      Code.ensure_loaded!(Clarity.Graph)
      Docs.fetch(Clarity.Graph)

      assert [{_key, docs}] =
               :ets.lookup(Docs, {Clarity.Graph, Clarity.Graph.module_info(:md5), :docs})

      assert docs == Code.fetch_docs(Clarity.Graph)
    end

    test "fetches the docs of a module that isn't loaded, or doesn't exist" do
      assert Docs.fetch(:"Elixir.Clarity.NoSuchModule") == {:error, :module_not_found}
    end
  end

  describe inspect(&Docs.moduledoc/1) do
    test "returns the module's Markdown documentation" do
      {:docs_v1, _, _, "text/markdown", %{"en" => doc}, _, _} = Code.fetch_docs(Clarity.Graph)

      assert Docs.moduledoc(Clarity.Graph) == doc
    end

    test "is nil for a module without documentation" do
      assert Docs.moduledoc(Clarity.Server) == nil
      assert Docs.moduledoc(:"Elixir.Clarity.NoSuchModule") == nil
    end
  end
end
