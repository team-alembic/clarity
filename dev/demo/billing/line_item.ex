defmodule Demo.Billing.LineItem do
  @moduledoc """
  A single billable line on an Invoice. `total_cents` is calculated; it's
  also stored as a real attribute so Invoice's `:total_cents` aggregate
  can sum it without needing aggregate-of-calculation support.
  """

  use Ash.Resource,
    domain: Demo.Billing,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]
  end

  calculations do
    calculate :gross_cents,
              :integer,
              expr(quantity * unit_price_cents)

    calculate :tax_cents,
              :integer,
              expr(fragment("?::int", quantity * unit_price_cents * tax_rate))
  end

  relationships do
    belongs_to :invoice, Demo.Billing.Invoice, allow_nil?: false
  end

  attributes do
    uuid_primary_key :id

    attribute :description, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 200
    end

    attribute :quantity, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    attribute :unit_price_cents, :integer do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :tax_rate, :decimal do
      allow_nil? false
      public? true
      default Decimal.new(0)
      constraints min: 0, max: 1
    end

    attribute :total_cents, :integer do
      public? true
      description "Stored gross + tax for aggregate summing on Invoice."
    end

    timestamps()
  end
end
