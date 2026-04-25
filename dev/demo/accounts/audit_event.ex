defmodule Demo.Accounts.AuditEvent do
  @moduledoc """
  Append-only log of state-changing actions in the system. Each event
  captures the actor (User), the affected target (polymorphic via
  `target_type` + `target_id`), and a JSON payload describing the change.
  """

  use Ash.Resource,
    domain: Demo.Accounts,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, create: :*]

    read :for_organization do
      argument :organization_id, :uuid, allow_nil?: false
      filter expr(organization_id == ^arg(:organization_id))
    end

    read :since do
      argument :since, :utc_datetime_usec, allow_nil?: false
      filter expr(occurred_at >= ^arg(:since))
    end
  end

  relationships do
    belongs_to :organization, Demo.Accounts.Organization, allow_nil?: false
    belongs_to :actor, Demo.Accounts.User, source_attribute: :actor_id
  end

  attributes do
    uuid_primary_key :id

    attribute :action, :atom do
      allow_nil? false
      public? true
      constraints one_of: [
                    :user_invited,
                    :user_accepted,
                    :user_revoked,
                    :token_issued,
                    :token_revoked,
                    :ticket_opened,
                    :ticket_closed,
                    :ticket_reassigned,
                    :invoice_paid,
                    :subscription_started,
                    :subscription_canceled
                  ]
    end

    attribute :target_type, :atom do
      public? true
      constraints one_of: [
                    :user,
                    :membership,
                    :api_token,
                    :project,
                    :ticket,
                    :invoice,
                    :subscription
                  ]
    end

    attribute :target_id, :uuid, public?: true
    attribute :payload, :map, public?: true, default: %{}

    attribute :occurred_at, :utc_datetime_usec do
      public? true
      allow_nil? false
      default &DateTime.utc_now/0
    end

    timestamps()
  end
end
