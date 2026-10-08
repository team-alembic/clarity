defmodule Demo.Projects.Sprint do
  @moduledoc """
  A time-boxed iteration on a Project. Tickets can be assigned to at most
  one Sprint at a time.
  """

  use Ash.Resource,
    domain: Demo.Projects,
    extensions: [AshStateMachine],
    data_layer: Ash.DataLayer.Ets

  resource do
    description """
    A time-boxed iteration on a Project. Tickets can be assigned to
    at most one Sprint at a time. Lifecycle moves from `:planned` to
    `:active`, then ends `:completed` or `:cancelled`.
    """
  end

  state_machine do
    state_attribute(:status)
    initial_states([:planned])
    default_initial_state(:planned)

    transitions do
      transition(:start, from: :planned, to: :active)
      transition(:end, from: :active, to: :completed)
      transition(:abort, from: :active, to: :cancelled)
    end
  end

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]

    update :start do
      accept []
      change transition_state(:active)
      change set_attribute(:starts_on, expr(today()))
    end

    update :end do
      accept []
      change transition_state(:completed)
      change set_attribute(:ends_on, expr(today()))
    end

    update :abort do
      accept []
      change transition_state(:cancelled)
      change set_attribute(:ends_on, expr(today()))
    end

    read :current do
      filter expr(status == :active)
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
              expr(fragment("date_part('day', ?::timestamp - ?::timestamp)", ends_on, starts_on))

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

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:planned, :active, :completed, :cancelled]
      default :planned
    end

    attribute :starts_on, :date, public?: true, allow_nil?: false
    attribute :ends_on, :date, public?: true

    timestamps()
  end
end
