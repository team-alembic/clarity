defmodule Clarity.Docs do
  @moduledoc false

  # Code.fetch_docs/1, kept for each loaded module as compiled: fetching reads
  # the module's file every time, and hints ask for a module's docs whenever a
  # page renders a link to it.
  #
  # A module's md5 covers its code, not its docs, so a recompile that changes
  # only documentation keeps it: Clarity.CodeReloader forgets the docs of the
  # modules each compile changes.

  @table __MODULE__

  @spec create_cache() :: :ets.table()
  def create_cache, do: :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

  @doc """
  Returns the module's docs, as `Code.fetch_docs/1` does.
  """
  @spec fetch(module()) :: term()
  def fetch(module), do: cached(module, :docs, fn -> Code.fetch_docs(module) end)

  @doc """
  Returns the module's documentation, in Markdown, in English, or nil.

  Hints want only this, and a module's docs can be large (a domain's code
  interface documents a function for each action), so it's kept on its own.
  """
  @spec moduledoc(module()) :: String.t() | nil
  def moduledoc(module) do
    cached(module, :moduledoc, fn ->
      case Code.fetch_docs(module) do
        {:docs_v1, _anno, _language, "text/markdown", %{"en" => doc}, _meta, _docs} -> doc
        _none -> nil
      end
    end)
  end

  @doc """
  Forgets what's kept for `modules`, recompiled or removed since.
  """
  @spec forget([module()]) :: :ok
  def forget(modules) do
    with table when table != :undefined <- :ets.whereis(@table) do
      for module <- modules, kind <- [:docs, :moduledoc], do: :ets.delete(table, {module, kind})
    end

    :ok
  end

  @spec cached(module(), atom(), (-> result)) :: result when result: term()
  defp cached(module, kind, fun) do
    with table when table != :undefined <- :ets.whereis(@table),
         true <- :erlang.module_loaded(module) do
      key = {module, kind}
      md5 = module.module_info(:md5)

      case :ets.lookup(table, key) do
        [{^key, ^md5, result}] ->
          result

        _stale ->
          result = fun.()
          :ets.insert(table, {key, md5, result})
          result
      end
    else
      _uncached -> fun.()
    end
  end
end
