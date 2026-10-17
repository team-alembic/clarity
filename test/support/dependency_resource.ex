defmodule Clarity.Test.DependencyResource do
  @moduledoc false

  # A resource as a Hex dependency might ship one:
  # undescribed, with an undocumented field and no policies, so every report
  # would find something to do about it. `claim/0` files it under the `:ash`
  # application, a Hex package in Clarity's mix.lock.

  use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id
    attribute :value, :string, public?: true
  end

  actions do
    defaults [:read]
  end

  @doc false
  @spec claim() :: :ok
  def claim do
    true = :ets.insert(Clarity.Config.ModuleApplications, {__MODULE__, :ash})
    :ok
  end
end
