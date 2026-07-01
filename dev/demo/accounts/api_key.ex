defmodule Demo.Accounts.ApiKey do
  @moduledoc false
  use Ash.Resource,
    domain: Demo.Accounts.Domain,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:api_key_hash, :expires_at]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :api_key_hash, :binary do
      allow_nil? false
      sensitive? true
    end

    attribute :expires_at, :utc_datetime_usec, allow_nil?: false
  end

  relationships do
    belongs_to :user, Demo.Accounts.User
  end
end
