defmodule Demo.Projects.TimeEntry do
  @moduledoc """
  A logged work interval against a Ticket by a User. Used for sum
  aggregates on Ticket / Project.
  """

  use Ash.Resource,
    domain: Demo.Projects,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    create :log do
      accept [:ticket_id, :user_id, :minutes, :note, :started_at, :ended_at]
    end

    read :for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
    end

    read :within do
      argument :from, :utc_datetime_usec, allow_nil?: false
      argument :to, :utc_datetime_usec, allow_nil?: false
      filter expr(started_at >= ^arg(:from) and started_at <= ^arg(:to))
    end
  end

  relationships do
    belongs_to :ticket, Demo.Projects.Ticket, allow_nil?: false
    belongs_to :user, Demo.Accounts.User, allow_nil?: false
  end

  attributes do
    uuid_primary_key :id

    attribute :minutes, :integer do
      allow_nil? false
      public? true
      constraints min: 1, max: 1440
    end

    attribute :note, :string, public?: true
    attribute :started_at, :utc_datetime_usec, public?: true, allow_nil?: false
    attribute :ended_at, :utc_datetime_usec, public?: true

    timestamps()
  end
end
