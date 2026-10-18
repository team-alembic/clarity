defmodule Demo.Projects.Sprint.Retrospective do
  @moduledoc """
  What a team took from a Sprint once it closed, beside
  `Demo.Projects.Sprint.Goal`.
  """

  use Ash.Resource,
    domain: Demo.Projects,
    data_layer: Ash.DataLayer.Ets

  resource do
    description "What the team kept, dropped and tried after a Sprint."
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  relationships do
    belongs_to :sprint, Demo.Projects.Sprint, allow_nil?: false
  end

  attributes do
    uuid_primary_key :id
    attribute :went_well, :string, public?: true, description: "What to keep doing."
    attribute :to_improve, :string, public?: true, description: "What to change next time."
  end
end
