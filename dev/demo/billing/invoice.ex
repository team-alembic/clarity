defmodule Demo.Billing.Invoice do
  @moduledoc """
  A periodic charge owed by an Organization for its Subscription. Total
  is the sum of LineItems and is exposed as an aggregate.
  """

  use Ash.Resource,
    domain: Demo.Billing,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    update :mark_paid do
      accept []
      change set_attribute(:status, :paid)
      change set_attribute(:paid_on, expr(today()))
    end

    update :void do
      accept []
      change set_attribute(:status, :void)
    end

    read :outstanding do
      filter expr(status in [:open, :overdue])
    end

    read :overdue do
      filter expr(status == :open and due_on < today())
    end
  end

  aggregates do
    count :line_count, :line_items
    sum :total_cents, :line_items, :total_cents
  end

  calculations do
    calculate :days_overdue,
              :integer,
              expr(
                if not is_nil(due_on) and status in [:open, :overdue] and due_on < today() do
                  fragment("date_part('day', ?::timestamp - ?::timestamp)", today(), due_on)
                else
                  0
                end
              )

    calculate :outstanding_cents,
              :integer,
              expr(
                if status in [:paid, :void] do
                  0
                else
                  total_cents
                end
              )
  end

  relationships do
    belongs_to :subscription, Demo.Billing.Subscription, allow_nil?: false

    has_many :line_items, Demo.Billing.LineItem
  end

  attributes do
    uuid_primary_key :id

    attribute :number, :string do
      allow_nil? false
      public? true
      constraints match: ~r/^INV-\d{6}$/
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:draft, :open, :paid, :overdue, :void]
      default :draft
    end

    attribute :issued_on, :date, public?: true, allow_nil?: false
    attribute :due_on, :date, public?: true
    attribute :paid_on, :date, public?: true

    timestamps()
  end

  identities do
    identity :unique_number, [:number], pre_check_with: Demo.Billing
  end
end
