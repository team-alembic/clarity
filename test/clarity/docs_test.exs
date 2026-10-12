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

      md5 = Clarity.Graph.module_info(:md5)
      assert [{_key, ^md5, docs}] = :ets.lookup(Docs, {Clarity.Graph, :docs})

      assert docs == Code.fetch_docs(Clarity.Graph)
    end

    test "fetches the docs of a module that isn't loaded, or doesn't exist" do
      assert Docs.fetch(:"Elixir.Clarity.NoSuchModule") == {:error, :module_not_found}
    end
  end

  describe inspect(&Docs.forget/1) do
    # Code.fetch_docs/1 reads a module's file from the code path, so the
    # module is written to one there.
    @tag :tmp_dir
    test "shows docs edited since, which leave the module's md5 as it was", %{tmp_dir: dir} do
      module = Clarity.DocsTest.Edited
      true = :code.add_patha(String.to_charlist(dir))
      on_exit(fn -> :code.del_path(String.to_charlist(dir)) end)

      compile(module, "Before.", dir)
      assert Docs.moduledoc(module) == "Before."
      md5 = module.module_info(:md5)

      compile(module, "After.", dir)
      assert module.module_info(:md5) == md5
      assert Docs.moduledoc(module) == "Before."

      assert :ok = Docs.forget([module])
      assert Docs.moduledoc(module) == "After."
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

  @spec compile(module(), String.t(), Path.t()) :: {:module, module()}
  defp compile(module, moduledoc, dir) do
    :code.purge(module)
    :code.delete(module)

    # mix test compiles without docs.
    docs? = Code.get_compiler_option(:docs)
    Code.put_compiler_option(:docs, true)

    [{^module, binary}] =
      try do
        Code.compile_string("""
        defmodule #{inspect(module)} do
          @moduledoc #{inspect(moduledoc)}
          def f, do: :ok
        end
        """)
      after
        Code.put_compiler_option(:docs, docs?)
      end

    path = Path.join(dir, "#{module}.beam")
    File.write!(path, binary)
    :code.purge(module)
    {:module, ^module} = :code.load_binary(module, String.to_charlist(path), binary)
  end
end
