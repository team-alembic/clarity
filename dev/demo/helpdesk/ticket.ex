defmodule Demo.Helpdesk.Ticket do
  @moduledoc """
  A customer-reported support issue. Optionally links to a Projects.Ticket
  when a support case is escalated to engineering — this is the
  cross-domain edge that the Application Diagram visualises.
  """

  use Ash.Resource,
    domain: Demo.Helpdesk,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: Ash.DataLayer.Ets

  policies do
    policy action_type(:read) do
      authorize_if expr(organization_id in ^actor(:organization_ids))
    end

    policy action(:link_to_project_ticket) do
      authorize_if expr(^actor(:role) in [:owner, :admin, :member])
    end
  end

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    create :open do
      accept [
        :organization_id,
        :customer_contact_id,
        :subject,
        :channel,
        :priority,
        :sla_policy_id
      ]

      change set_attribute(:status, :new)
    end

    update :resolve do
      accept []
      change set_attribute(:status, :resolved)
      change set_attribute(:resolved_at, expr(now()))
    end

    update :reopen do
      accept []
      change set_attribute(:status, :open)
      change set_attribute(:resolved_at, nil)
    end

    update :assign do
      accept [:assignee_id]
    end

    update :link_to_project_ticket do
      accept [:linked_project_ticket_id]
    end

    read :pending do
      filter expr(status in [:new, :open, :pending])
    end

    read :overdue do
      filter expr(not is_nil(sla_due_at) and sla_due_at < now() and status not in [:resolved, :closed])
    end
  end

  aggregates do
    count :conversation_count, :conversations
  end

  calculations do
    calculate :is_overdue?,
              :boolean,
              expr(
                not is_nil(sla_due_at) and sla_due_at < now() and
                  status not in [:resolved, :closed]
              )
  end

  relationships do
    belongs_to :organization, Demo.Accounts.Organization, allow_nil?: false
    belongs_to :customer_contact, Demo.Helpdesk.CustomerContact, allow_nil?: false
    belongs_to :assignee, Demo.Accounts.User
    belongs_to :sla_policy, Demo.Helpdesk.SlaPolicy
    belongs_to :linked_project_ticket, Demo.Projects.Ticket

    has_many :conversations, Demo.Helpdesk.Conversation, destination_attribute: :helpdesk_ticket_id
  end

  attributes do
    uuid_primary_key :id

    attribute :subject, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 200
    end

    attribute :channel, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:email, :chat, :form, :api, :phone]
      default :email
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:new, :open, :pending, :resolved, :closed]
      default :new
    end

    attribute :priority, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :normal, :high, :urgent]
      default :normal
    end

    attribute :sla_due_at, :utc_datetime_usec, public?: true
    attribute :resolved_at, :utc_datetime_usec, public?: true

    timestamps()
  end
end
