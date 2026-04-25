defmodule Demo.Projects.Sprint do
  @moduledoc """
  A time-boxed iteration on a Project. Tickets can be assigned to at most
  one Sprint at a time.
  """

  use Ash.Resource,
    domain: Demo.Projects,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    update :start do
      accept []
      change set_attribute(:starts_on, expr(today()))
    end

    update :complete do
      accept []
      change set_attribute(:ends_on, expr(today()))
    end

    read :current do
      filter expr(starts_on <= today() and (is_nil(ends_on) or ends_on >= today()))
    end
  end

  aggregates do
    count :ticket_count, :tickets
    count :closed_ticket_count, :tickets do
      filter expr(status == :closed)
    end
    sum :committed_points, :tickets, :points
  end

  calculations do
    calculate :duration_days,
              :integer,
              expr(
                fragment("date_part('day', ?::timestamp - ?::timestamp)", ends_on, starts_on)
              )

    calculate :completion_ratio,
              :float,
              expr(
                if ticket_count == 0 do
                  0.0
                else
                  closed_ticket_count / ticket_count
                end
              )
  end

  relationships do
    belongs_to :project, Demo.Projects.Project, allow_nil?: false
    has_many :tickets, Demo.Projects.Ticket
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 80
    end

    attribute :goal, :string, public?: true
    attribute :starts_on, :date, public?: true, allow_nil?: false
    attribute :ends_on, :date, public?: true

    timestamps()
  end
end
