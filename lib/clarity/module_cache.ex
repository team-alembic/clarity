defmodule Clarity.ModuleCache do
  @moduledoc false

  @table __MODULE__

  @spec create_table() :: :ets.table()
  def create_table, do: :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

  @doc """
  Returns the result kept for `key` while the code of `modules` stays the
  same, or works it out with `fun` and keeps it.
  """
  @spec fetch(term(), [module()], (-> result)) :: result when result: term()
  def fetch(key, modules, fun) do
    case :ets.whereis(@table) do
      :undefined ->
        fun.()

      table ->
        version = Enum.map(modules, &md5/1)

        case :ets.lookup(table, key) do
          [{^key, ^version, result}] ->
            result

          _stale ->
            result = fun.()
            :ets.insert(table, {key, version, result})
            result
        end
    end
  end

  @spec md5(module()) :: binary() | nil
  defp md5(module) do
    case Code.ensure_loaded(module) do
      {:module, ^module} -> module.module_info(:md5)
      _not_loaded -> nil
    end
  end
end
