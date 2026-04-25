defmodule Demo.Billing.Plan do
  @moduledoc """
  Static catalog entry. Subscriptions reference a Plan; price + features
  are denormalised onto the Subscription at creation so plan changes
  don't retroactively alter past invoices.
  """

  use Ash.Resource,
    domain: Demo.Billing,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    update :archive do
      accept []
      change set_attribute(:active?, false)
    end

    read :active do
      filter expr(active? == true)
    end
  end

  aggregates do
    count :subscription_count, :subscriptions
    count :active_subscription_count, :subscriptions do
      filter expr(status == :active)
    end
  end

  relationships do
    has_many :subscriptions, Demo.Billing.Subscription
  end

  attributes do
    uuid_primary_key :id

    attribute :code, :string do
      allow_nil? false
      public? true
      constraints match: ~r/^[a-z0-9_]+$/, min_length: 1, max_length: 40
    end

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 80
    end

    attribute :price_cents, :integer do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :currency, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:USD, :EUR, :GBP, :JPY, :AUD]
      default :USD
    end

    attribute :features, {:array, :atom} do
      public? true
      allow_nil? false
      default []
      constraints items: [
                    one_of: [
                      :unlimited_projects,
                      :advanced_reporting,
                      :sso,
                      :scim,
                      :priority_support,
                      :custom_domains,
                      :audit_log,
                      :api_access
                    ]
                  ]
    end

    attribute :active?, :boolean, public?: true, allow_nil?: false, default: true

    timestamps()
  end

  identities do
    identity :unique_code, [:code], pre_check_with: Demo.Billing
  end
end
