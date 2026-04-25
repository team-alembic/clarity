defmodule Demo.Accounts.ApiToken do
  @moduledoc """
  Programmatic credential scoped to an Organization (and optionally a single
  User). The plaintext secret is shown once at creation; only the hash is
  ever stored.
  """

  use Ash.Resource,
    domain: Demo.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: Ash.DataLayer.Ets

  policies do
    policy action_type(:read) do
      authorize_if expr(organization_id in ^actor(:organization_ids))
    end

    policy action_type([:create, :destroy]) do
      authorize_if expr(^actor(:role) in [:owner, :admin])
    end
  end

  actions do
    default_accept :*
    defaults [:read, :destroy]

    create :issue do
      accept [:name, :organization_id, :user_id, :scopes, :expires_at]
      argument :plaintext_secret, :string, allow_nil?: false, sensitive?: true
      change set_attribute(:prefix, expr(fragment("substr(?, 1, 8)", ^arg(:plaintext_secret))))
    end

    update :touch do
      accept []
      change set_attribute(:last_used_at, expr(now()))
    end

    read :active do
      filter expr(is_nil(revoked_at) and (is_nil(expires_at) or expires_at > now()))
    end
  end

  relationships do
    belongs_to :organization, Demo.Accounts.Organization, allow_nil?: false
    belongs_to :user, Demo.Accounts.User
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 80
    end

    attribute :prefix, :string, public?: true
    attribute :hashed_secret, :string, sensitive?: true, allow_nil?: false

    attribute :scopes, {:array, :atom} do
      public? true
      allow_nil? false
      default []
      constraints items: [one_of: [:read, :write, :admin, :billing]]
    end

    attribute :expires_at, :utc_datetime_usec, public?: true
    attribute :last_used_at, :utc_datetime_usec, public?: true
    attribute :revoked_at, :utc_datetime_usec, public?: true

    timestamps()
  end
end
