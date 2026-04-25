defmodule Demo.Projects.Attachment do
  @moduledoc """
  A file attached to either a Ticket or a Comment. We model the
  polymorphic parent with two nullable foreign keys (`ticket_id`,
  `comment_id`) — exactly one of which is set for a given attachment.
  """

  use Ash.Resource,
    domain: Demo.Projects,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    read :for_ticket do
      argument :ticket_id, :uuid, allow_nil?: false
      filter expr(ticket_id == ^arg(:ticket_id))
    end

    read :for_comment do
      argument :comment_id, :uuid, allow_nil?: false
      filter expr(comment_id == ^arg(:comment_id))
    end
  end

  validations do
    validate present([:ticket_id, :comment_id], at_least: 1, at_most: 1) do
      message "Attachment must belong to exactly one of a Ticket or a Comment."
    end
  end

  relationships do
    belongs_to :ticket, Demo.Projects.Ticket
    belongs_to :comment, Demo.Projects.Comment
    belongs_to :uploaded_by, Demo.Accounts.User, allow_nil?: false
  end

  attributes do
    uuid_primary_key :id

    attribute :filename, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 255
    end

    attribute :content_type, :string do
      allow_nil? false
      public? true
      default "application/octet-stream"
    end

    attribute :size_bytes, :integer do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :url, :string, public?: true

    timestamps()
  end
end
