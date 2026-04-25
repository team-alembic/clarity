defmodule Demo.Billing.PaymentMethod do
  @moduledoc """
  A stored payment instrument (card, bank account, etc.). Sensitive fields
  are masked; only metadata such as brand + last four digits is exposed.
  """

  use Ash.Resource,
    domain: Demo.Billing,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    update :make_default do
      accept []
      change set_attribute(:default?, true)
    end
  end

  relationships do
    belongs_to :organization, Demo.Accounts.Organization, allow_nil?: false
  end

  attributes do
    uuid_primary_key :id

    attribute :brand, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:visa, :mastercard, :amex, :discover, :ach]
    end

    attribute :last4, :string do
      allow_nil? false
      public? true
      constraints match: ~r/^\d{4}$/
    end

    attribute :exp_month, :integer do
      public? true
      constraints min: 1, max: 12
    end

    attribute :exp_year, :integer do
      public? true
      constraints min: 2024, max: 2099
    end

    attribute :default?, :boolean, public?: true, allow_nil?: false, default: false

    timestamps()
  end
end
