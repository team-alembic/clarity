defmodule Demo.Helpdesk.CustomerContact do
  @moduledoc """
  An external person who has contacted us. Distinct from a User: they do
  not have credentials in this system.
  """

  use Ash.Resource,
    domain: Demo.Helpdesk,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    read :by_email do
      argument :email, :string, allow_nil?: false
      filter expr(email == ^arg(:email))
    end
  end

  aggregates do
    count :ticket_count, :tickets
    count :open_ticket_count, :tickets do
      filter expr(status not in [:resolved, :closed])
    end
  end

  relationships do
    belongs_to :organization, Demo.Accounts.Organization, allow_nil?: false
    has_many :tickets, Demo.Helpdesk.Ticket
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string do
      allow_nil? false
      public? true
      sensitive? true
      constraints match: ~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/
    end

    attribute :name, :string, public?: true

    attribute :phone, :string do
      public? true
      sensitive? true
    end

    attribute :source, :atom do
      public? true
      constraints one_of: [:website, :referral, :marketplace, :outbound, :unknown]
      default :unknown
    end

    timestamps()
  end

  identities do
    identity :unique_email_per_org, [:organization_id, :email], pre_check_with: Demo.Helpdesk
  end
end
