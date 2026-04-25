defmodule Demo.Billing.Subscription do
  @moduledoc """
  An Organization's active commitment to a Plan. Generates Invoices on
  each billing cycle.
  """

  use Ash.Resource,
    domain: Demo.Billing,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    create :start_subscription do
      accept [:organization_id, :plan_id, :seats]
      change set_attribute(:status, :trialing)
      change set_attribute(:started_on, expr(today()))
    end

    update :activate do
      accept []
      change set_attribute(:status, :active)
    end

    update :cancel do
      accept []
      change set_attribute(:status, :canceled)
      change set_attribute(:canceled_on, expr(today()))
    end

    update :resume do
      accept []
      change set_attribute(:status, :active)
      change set_attribute(:canceled_on, nil)
    end

    read :active do
      filter expr(status == :active)
    end
  end

  aggregates do
    count :invoice_count, :invoices
    count :outstanding_invoice_count, :invoices do
      filter expr(status in [:open, :overdue])
    end
    sum :lifetime_billed_cents, :invoices, :total_cents
  end

  calculations do
    calculate :in_trial?,
              :boolean,
              expr(status == :trialing)

    calculate :is_cancelled?,
              :boolean,
              expr(status == :canceled)
  end

  relationships do
    belongs_to :organization, Demo.Accounts.Organization, allow_nil?: false
    belongs_to :plan, Demo.Billing.Plan, allow_nil?: false

    has_many :invoices, Demo.Billing.Invoice
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:trialing, :active, :past_due, :canceled, :paused]
      default :trialing
    end

    attribute :seats, :integer do
      allow_nil? false
      public? true
      constraints min: 1
      default 1
    end

    attribute :started_on, :date, public?: true
    attribute :current_period_end, :date, public?: true
    attribute :canceled_on, :date, public?: true

    timestamps()
  end
end
