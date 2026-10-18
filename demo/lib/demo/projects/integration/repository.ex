defmodule Demo.Projects.Integration.Repository do
  @moduledoc """
  A code repository linked to a Project. `Demo.Projects.Integration` is only
  a namespace, not a resource, so Clarity groups its resources under its name.
  """

  use Ash.Resource,
    domain: Demo.Projects,
    data_layer: Ash.DataLayer.Ets

  resource do
    description "A code repository whose commits mention a Project's Tickets."
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  relationships do
    belongs_to :project, Demo.Projects.Project, allow_nil?: false
  end

  attributes do
    uuid_primary_key :id
    attribute :url, :string, allow_nil?: false, public?: true, description: "Where it's hosted."
  end
end
