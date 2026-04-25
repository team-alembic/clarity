defmodule Demo.Helpdesk.Conversation do
  @moduledoc """
  A back-and-forth thread on a Helpdesk Ticket. A ticket can have multiple
  conversations (e.g. one over email, one over chat).
  """

  use Ash.Resource,
    domain: Demo.Helpdesk,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    update :end_conversation do
      accept []
      change set_attribute(:ended_at, expr(now()))
    end
  end

  aggregates do
    count :message_count, :messages
    count :inbound_count, :messages do
      filter expr(direction == :inbound)
    end
  end

  relationships do
    belongs_to :helpdesk_ticket, Demo.Helpdesk.Ticket, allow_nil?: false
    has_many :messages, Demo.Helpdesk.Message
  end

  attributes do
    uuid_primary_key :id

    attribute :started_at, :utc_datetime_usec do
      allow_nil? false
      public? true
      default &DateTime.utc_now/0
    end

    attribute :ended_at, :utc_datetime_usec, public?: true
    attribute :transcript, :map, public?: true, default: %{}
    attribute :summary, :string, public?: true

    timestamps()
  end
end
