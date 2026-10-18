defmodule Demo.Projects.Integration.ChatChannel do
  @moduledoc """
  A chat channel that hears about a Project's Tickets, beside
  `Demo.Projects.Integration.Repository`.
  """

  use Ash.Resource,
    domain: Demo.Projects,
    data_layer: Ash.DataLayer.Ets

  resource do
    description "A chat channel told when a Project's Tickets change."
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  relationships do
    belongs_to :project, Demo.Projects.Project, allow_nil?: false
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, description: "The channel's name."
  end
end
