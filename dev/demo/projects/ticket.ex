defmodule Demo.Projects.Ticket do
  @moduledoc """
  The richest resource in the demo. A unit of work in a Project.

  Has multiple named relationships to User (reporter, assignee), a self
  reference (parent_ticket), a many-to-many through TicketLabel, and several
  has_many children (comments, attachments, time entries).
  """

  use Ash.Resource,
    domain: Demo.Projects,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: Ash.DataLayer.Ets

  policies do
    bypass actor_attribute_equals(:admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(project.organization_id in ^actor(:organization_ids))
    end

    policy action(:close) do
      authorize_if expr(reporter_id == ^actor(:id))
      authorize_if expr(assignee_id == ^actor(:id))
      authorize_if expr(^actor(:role) in [:owner, :admin])
    end

    policy action(:reassign) do
      authorize_if expr(^actor(:role) in [:owner, :admin, :member])
    end
  end

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    create :open do
      accept [:project_id, :title, :body, :priority, :reporter_id, :assignee_id]
      change set_attribute(:status, :open)
    end

    update :close do
      accept []
      change set_attribute(:status, :closed)
      change set_attribute(:closed_at, expr(now()))
    end

    update :reopen do
      accept []
      change set_attribute(:status, :open)
      change set_attribute(:closed_at, nil)
    end

    update :reassign do
      accept [:assignee_id]
    end

    update :transition do
      accept []
      argument :to, :atom, allow_nil?: false, constraints: [one_of: [:open, :in_progress, :review, :closed, :wont_fix]]
      change set_attribute(:status, arg(:to))
    end

    read :open_only do
      filter expr(status == :open)
    end

    read :for_assignee do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(assignee_id == ^arg(:user_id))
    end

    read :high_priority do
      filter expr(priority in [:high, :urgent])
    end
  end

  aggregates do
    count :comment_count, :comments
    count :attachment_count, :attachments
    sum :total_minutes, :time_entries, :minutes
    count :label_count, :ticket_labels
  end

  calculations do
    calculate :age_in_days,
              :integer,
              expr(fragment("date_part('day', ? - ?)", now(), inserted_at))

    calculate :is_overdue?,
              :boolean,
              expr(not is_nil(due_at) and due_at < now() and status != :closed)

    calculate :code, :string, expr(fragment("? || '-' || ?", project.key, position))
  end

  relationships do
    belongs_to :project, Demo.Projects.Project, allow_nil?: false
    belongs_to :sprint, Demo.Projects.Sprint
    belongs_to :reporter, Demo.Accounts.User
    belongs_to :assignee, Demo.Accounts.User
    belongs_to :parent_ticket, __MODULE__

    has_many :comments, Demo.Projects.Comment
    has_many :attachments, Demo.Projects.Attachment, destination_attribute: :ticket_id
    has_many :time_entries, Demo.Projects.TimeEntry
    has_many :ticket_labels, Demo.Projects.TicketLabel
    has_many :sub_tickets, __MODULE__, destination_attribute: :parent_ticket_id

    many_to_many :labels, Demo.Projects.Label do
      through Demo.Projects.TicketLabel
      source_attribute_on_join_resource :ticket_id
      destination_attribute_on_join_resource :label_id
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 200
    end

    attribute :body, :string, public?: true

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:open, :in_progress, :review, :closed, :wont_fix]
      default :open
    end

    attribute :priority, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :normal, :high, :urgent]
      default :normal
    end

    attribute :points, :integer do
      public? true
      constraints min: 0, max: 100
    end

    attribute :position, :decimal, public?: true, default: Decimal.new(0)
    attribute :due_at, :utc_datetime_usec, public?: true
    attribute :closed_at, :utc_datetime_usec, public?: true

    timestamps()
  end
end
