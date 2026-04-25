defmodule Demo.Helpdesk.Message do
  @moduledoc """
  Single utterance inside a Conversation. Sender is polymorphic: either a
  User (outbound) or a CustomerContact (inbound), modelled with two
  nullable foreign keys.
  """

  use Ash.Resource,
    domain: Demo.Helpdesk,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*]
  end

  validations do
    validate present([:sender_user_id, :sender_contact_id], at_least: 1, at_most: 1)
  end

  relationships do
    belongs_to :conversation, Demo.Helpdesk.Conversation, allow_nil?: false
    belongs_to :sender_user, Demo.Accounts.User
    belongs_to :sender_contact, Demo.Helpdesk.CustomerContact
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string do
      allow_nil? false
      public? true
      constraints min_length: 1
    end

    attribute :direction, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:inbound, :outbound]
    end

    attribute :sent_at, :utc_datetime_usec do
      allow_nil? false
      public? true
      default &DateTime.utc_now/0
    end

    timestamps()
  end
end
