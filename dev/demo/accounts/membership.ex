defmodule Demo.Accounts.Membership do
  @moduledoc """
  Join between Organization and User with extra metadata: role, invited_at,
  accepted_at. Drives RBAC across the rest of the app.
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
      authorize_if expr(organization_id in ^actor(:organization_ids))
    end

    policy action(:invite) do
      authorize_if expr(^actor(:role) in [:owner, :admin])
    end

    policy action(:revoke) do
      authorize_if expr(role != :owner)
      forbid_if expr(user_id == ^actor(:id))
    end
  end

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    create :invite do
      accept [:organization_id, :user_id, :role]
      change set_attribute(:invited_at, expr(now()))
    end

    update :accept do
      accept []
      change set_attribute(:accepted_at, expr(now()))
    end

    update :revoke do
      accept []
      change set_attribute(:revoked_at, expr(now()))
    end

    read :pending do
      filter expr(is_nil(accepted_at) and is_nil(revoked_at))
    end
  end

  relationships do
    belongs_to :organization, Demo.Accounts.Organization, allow_nil?: false
    belongs_to :user, Demo.Accounts.User, allow_nil?: false
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :atom do
      public? true
      allow_nil? false
      constraints one_of: [:owner, :admin, :member, :guest]
      default :member
    end

    attribute :invited_at, :utc_datetime_usec, public?: true
    attribute :accepted_at, :utc_datetime_usec, public?: true
    attribute :revoked_at, :utc_datetime_usec, public?: true

    timestamps()
  end

  identities do
    identity :one_per_org_user, [:organization_id, :user_id], pre_check_with: Demo.Accounts
  end
end
