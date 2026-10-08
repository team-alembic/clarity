defmodule Demo.Billing.Subscription do
  @moduledoc """
  An Organization's active commitment to a Plan. Generates Invoices on
  each billing cycle.
  """

  use Ash.Resource,
    domain: Demo.Billing,
    extensions: [AshStateMachine],
    data_layer: Ash.DataLayer.Ets

  resource do
    description """
    An Organization's active commitment to a Plan. Generates an
    Invoice on each billing cycle and tracks lifecycle (`trialing`,
    `active`, `past_due`, `canceled`).
    """
  end

  state_machine do
    state_attribute(:status)
    initial_states([:trialing])
    default_initial_state(:trialing)

    transitions do
      transition(:convert, from: :trialing, to: :active)
      transition(:abandon, from: :trialing, to: :canceled)
      transition(:payment_failed, from: :active, to: :past_due)
      transition(:retry_succeeds, from: :past_due, to: :active)
      transition(:final_dunning, from: :past_due, to: :canceled)
      transition(:user_cancels, from: :active, to: :canceled)
    end
  end

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    create :start_subscription do
      accept [:organization_id, :plan_id, :seats]
      change set_attribute(:started_on, expr(today()))
    end

    update :convert do
      description "Converts a trial into a paid subscription."
      accept []
      change transition_state(:active)
    end

    update :abandon do
      description "Ends a trial that was never converted."
      accept []
      change transition_state(:canceled)
      change set_attribute(:canceled_on, expr(today()))
    end

    update :payment_failed do
      accept []
      change transition_state(:past_due)
    end

    update :retry_succeeds do
      description "A retried payment went through."
      accept []
      change transition_state(:active)
    end

    update :final_dunning do
      description "Cancels after the last dunning attempt fails."
      accept []
      change transition_state(:canceled)
      change set_attribute(:canceled_on, expr(today()))
    end

    update :user_cancels do
      accept []
      change transition_state(:canceled)
      change set_attribute(:canceled_on, expr(today()))
    end

    read :active do
      filter expr(status == :active)
    end
  end

  aggregates do
    count :invoice_count, :invoices

    count :outstanding_invoice_count, :invoices do
      filter expr(status in [:sent, :overdue])
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
      constraints one_of: [:trialing, :active, :past_due, :canceled]
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
