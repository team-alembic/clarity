defmodule Demo.Projects.Ticket.Snapshot do
  @moduledoc false

  # A Ticket as it stood at a point in time, kept for burndown and other
  # reports: the same ending under several resources, which Clarity gathers
  # into a group of its own.

  use Ash.Resource,
    domain: Demo.Projects,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:read, create: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :source_id, :uuid, allow_nil?: false, public?: true
    attribute :state, :map, public?: true
    create_timestamp :taken_at
  end
end
