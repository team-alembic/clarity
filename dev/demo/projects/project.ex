defmodule Demo.Projects.Project do
  @moduledoc """
  A unit of work owned by an Organization. Has a lead (User), zero or more
  sprints, tickets, and labels. The `key` is a short prefix shown on
  tickets, e.g. "ORB-42".
  """

  use Ash.Resource,
    domain: Demo.Projects,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: Ash.DataLayer.Ets

  policies do
    policy action_type(:read) do
      authorize_if expr(organization_id in ^actor(:organization_ids))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:owner, :admin, :member])
    end
  end

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    update :archive do
      accept []
      change set_attribute(:archived?, true)
    end

    update :unarchive do
      accept []
      change set_attribute(:archived?, false)
    end

    read :active do
      filter expr(archived? == false)
    end

    read :by_key do
      argument :key, :string, allow_nil?: false
      filter expr(key == ^arg(:key))
    end
  end

  aggregates do
    count :ticket_count, :tickets
    count :open_ticket_count, :tickets do
      filter expr(status not in [:closed, :wont_fix])
    end
    count :sprint_count, :sprints
    count :label_count, :labels
    sum :total_time_minutes, [:tickets, :time_entries], :minutes
    first :latest_sprint_name, :sprints, :name do
      sort starts_on: :desc
    end
  end

  calculations do
    calculate :age_in_days,
              :integer,
              expr(fragment("date_part('day', ? - ?)", now(), inserted_at))

    calculate :is_overdue?,
              :boolean,
              expr(not is_nil(target_date) and target_date < today() and not archived?)
  end

  relationships do
    belongs_to :organization, Demo.Accounts.Organization, allow_nil?: false
    belongs_to :lead, Demo.Accounts.User

    has_many :sprints, Demo.Projects.Sprint
    has_many :tickets, Demo.Projects.Ticket
    has_many :labels, Demo.Projects.Label
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 120
    end

    attribute :key, :string do
      allow_nil? false
      public? true
      constraints match: ~r/^[A-Z][A-Z0-9]{1,9}$/
      description "Short uppercase prefix used in ticket numbers, e.g. \"ORB\"."
    end

    attribute :color, :string do
      public? true
      constraints match: ~r/^#[0-9a-fA-F]{6}$/
      default "#3b82f6"
    end

    attribute :archived?, :boolean, public?: true, allow_nil?: false, default: false
    attribute :started_on, :date, public?: true
    attribute :target_date, :date, public?: true
    attribute :description, :string, public?: true

    timestamps()
  end

  identities do
    identity :unique_key_per_org, [:organization_id, :key], pre_check_with: Demo.Projects
  end
end
