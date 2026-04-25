defmodule Demo.Accounts.User do
  @moduledoc false
  use Ash.Resource,
    domain: Demo.Accounts,
    authorizers: [
      Ash.Policy.Authorizer
    ],
    data_layer: Ash.DataLayer.Ets

  multitenancy do
    strategy :attribute
    attribute :org
    global? true
  end

  policies do
    bypass always() do
      authorize_if actor_attribute_equals(:admin, true)
    end

    policy action_type(:read) do
      authorize_if expr(id == ^actor(:id))
    end
  end

  actions do
    default_accept :*
    read :me, filter: [id: actor(:id)]
    read :read, primary?: true

    read :by_id do
      argument :id, :uuid

      filter expr(id == ^arg(:id))
    end

    read :should_be_hidden

    read :by_name do
      argument :first_name, :string, allow_nil?: false
      argument :last_name, :string, allow_nil?: false

      filter expr(first_name == ^arg(:first_name) and last_name == ^arg(:last_name))
    end

    create :create
    update :update, primary?: true
    update :update2
    destroy :destroy
  end

  validations do
    validate present([:first_name, :last_name], at_least: 1)
  end

  aggregates do
    count :admin_count, __MODULE__ do
      filter expr(admin == true)
    end
  end

  calculations do
    calculate :is_super_admin?, :boolean, expr(admin && representative)

    calculate :full_name,
              :string,
              expr(
                fragment(
                  "? || ' ' || ?",
                  coalesce(first_name, ""),
                  coalesce(last_name, "")
                )
              )

    calculate :multi_arguments,
              :string,
              expr(
                "Arg1: " <>
                  ^arg(:arg1) <>
                  ", Arg2: " <>
                  if(^arg(:arg2), do: "Yes", else: "No") <> ", Arg3: " <> ^arg(:arg3)
              ) do
      argument :arg1, :string do
        allow_nil? false
        constraints allow_empty?: false
      end

      argument :arg2, :boolean

      argument :arg3, :float do
        allow_nil? true
      end
    end
  end

  relationships do
    belongs_to :manager, __MODULE__ do
      attribute_writable? true
    end

    has_many :memberships, Demo.Accounts.Membership
    has_many :api_tokens, Demo.Accounts.ApiToken
    has_many :authored_audit_events, Demo.Accounts.AuditEvent, destination_attribute: :actor_id
    has_many :reported_tickets, Demo.Projects.Ticket, destination_attribute: :reporter_id
    has_many :assigned_tickets, Demo.Projects.Ticket, destination_attribute: :assignee_id
    has_many :led_projects, Demo.Projects.Project, destination_attribute: :lead_id
    has_many :time_entries, Demo.Projects.TimeEntry
    has_many :uploaded_attachments, Demo.Projects.Attachment, destination_attribute: :uploaded_by_id
    has_many :authored_comments, Demo.Projects.Comment, destination_attribute: :author_id
    has_many :handled_helpdesk_tickets, Demo.Helpdesk.Ticket, destination_attribute: :assignee_id
  end

  attributes do
    uuid_primary_key :id

    attribute :first_name, :string do
      constraints min_length: 1
      public? true
    end

    attribute :last_name, :string do
      constraints min_length: 1
      public? true
    end

    attribute :metadata, :map do
      public? true
    end

    attribute :representative, :boolean do
      allow_nil? false
      public? true
      default false

      description """
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
      eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim
      veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
      consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse
      cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non
      proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
      """
    end

    attribute :admin, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :api_key, :string do
      sensitive? true
    end

    attribute :date_of_birth, :date do
      public? true
      sensitive? true
    end

    attribute :type, :atom do
      public? true
      constraints one_of: [:type1, :type2]
      default :type1
    end

    attribute :types, {:array, :atom} do
      public? true
      constraints items: [one_of: [:type1, :type2]]
    end

    attribute :tags, {:array, :string} do
      public? true
    end

    attribute :email, :string do
      public? true
      sensitive? true
      constraints match: ~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/
    end

    attribute :avatar_url, :string, public?: true
    attribute :last_login_at, :utc_datetime_usec, public?: true

    attribute :locale, :atom do
      public? true
      allow_nil? false
      constraints one_of: [:en, :de, :fr, :es, :ja, :pt]
      default :en
    end

    attribute :org, :string

    timestamps()
  end
end
