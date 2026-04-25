defmodule Demo.Accounts.Organization do
  @moduledoc """
  Tenant root. Every Project, Helpdesk Ticket, Subscription, etc. belongs
  to an Organization. Plan tier drives feature gating via policies.
  """

  use Ash.Resource,
    domain: Demo.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: Ash.DataLayer.Ets

  policies do
    bypass actor_attribute_equals(:admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(id in ^actor(:organization_ids))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:admin, true)
    end
  end

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    read :by_slug do
      argument :slug, :string, allow_nil?: false
      filter expr(slug == ^arg(:slug))
    end

    update :start_trial do
      change set_attribute(:trial_ends_at, expr(fragment("?", now()) |> ago(-14, :day)))
    end
  end

  aggregates do
    count :member_count, :memberships
    count :active_user_count, :memberships do
      filter expr(role != :guest)
    end
    count :project_count, :projects
  end

  calculations do
    calculate :on_trial?, :boolean, expr(not is_nil(trial_ends_at) and trial_ends_at > now())
    calculate :seat_utilization, :float, expr(member_count / 50.0)
  end

  relationships do
    has_many :memberships, Demo.Accounts.Membership
    has_many :api_tokens, Demo.Accounts.ApiToken
    has_many :audit_events, Demo.Accounts.AuditEvent
    has_many :projects, Demo.Projects.Project
    has_many :helpdesk_tickets, Demo.Helpdesk.Ticket
    has_one :subscription, Demo.Billing.Subscription
    has_many :payment_methods, Demo.Billing.PaymentMethod
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
      constraints match: ~r/^[a-z0-9\-]+$/, min_length: 1, max_length: 60
      description "URL-safe identifier; must be unique organization-wide."
    end

    attribute :plan_tier, :atom do
      public? true
      allow_nil? false
      constraints one_of: [:free, :starter, :growth, :enterprise]
      default :free
    end

    attribute :trial_ends_at, :utc_datetime_usec, public?: true
    attribute :settings, :map, public?: true, default: %{}

    timestamps()
  end

  identities do
    identity :unique_slug, [:slug], pre_check_with: Demo.Accounts
  end
end
