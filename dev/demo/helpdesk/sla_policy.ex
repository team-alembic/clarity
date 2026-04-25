defmodule Demo.Helpdesk.SlaPolicy do
  @moduledoc """
  Service-level commitments configurable per Organization. The
  `applies_when` map carries the matching rules (e.g. priority filters).
  """

  use Ash.Resource,
    domain: Demo.Helpdesk,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]
  end

  aggregates do
    count :ticket_count, :tickets
  end

  relationships do
    belongs_to :organization, Demo.Accounts.Organization, allow_nil?: false
    has_many :tickets, Demo.Helpdesk.Ticket
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 80
    end

    attribute :response_minutes, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :resolution_minutes, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :applies_when, :map, public?: true, default: %{}

    timestamps()
  end
end
