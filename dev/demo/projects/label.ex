defmodule Demo.Projects.Label do
  @moduledoc """
  A coloured tag scoped to a Project. Many-to-many with Tickets through
  TicketLabel.
  """

  use Ash.Resource,
    domain: Demo.Projects,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]
  end

  aggregates do
    count :ticket_count, :tickets
  end

  relationships do
    belongs_to :project, Demo.Projects.Project, allow_nil?: false

    many_to_many :tickets, Demo.Projects.Ticket do
      through Demo.Projects.TicketLabel
      source_attribute_on_join_resource :label_id
      destination_attribute_on_join_resource :ticket_id
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 40
    end

    attribute :color, :string do
      public? true
      constraints match: ~r/^#[0-9a-fA-F]{6}$/
      default "#94a3b8"
    end

    attribute :description, :string, public?: true

    timestamps()
  end

  identities do
    identity :unique_per_project, [:project_id, :name], pre_check_with: Demo.Projects
  end
end
