defmodule Demo.Projects.Comment do
  @moduledoc """
  A user-authored note attached to a Ticket. Can have its own Attachments.
  """

  use Ash.Resource,
    domain: Demo.Projects,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    update :edit do
      accept [:body]
      change set_attribute(:edited_at, expr(now()))
    end
  end

  aggregates do
    count :attachment_count, :attachments
  end

  relationships do
    belongs_to :ticket, Demo.Projects.Ticket, allow_nil?: false
    belongs_to :author, Demo.Accounts.User, allow_nil?: false

    has_many :attachments, Demo.Projects.Attachment, destination_attribute: :comment_id
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string do
      allow_nil? false
      public? true
      constraints min_length: 1
    end

    attribute :edited_at, :utc_datetime_usec, public?: true

    timestamps()
  end
end
