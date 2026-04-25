defmodule Demo.Projects.TicketLabel do
  @moduledoc """
  Pure join between Ticket and Label.
  """

  use Ash.Resource,
    domain: Demo.Projects,
    data_layer: Ash.DataLayer.Ets

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*]
  end

  relationships do
    belongs_to :ticket, Demo.Projects.Ticket, allow_nil?: false, primary_key?: true
    belongs_to :label, Demo.Projects.Label, allow_nil?: false, primary_key?: true
  end

  attributes do
    timestamps()
  end
end
