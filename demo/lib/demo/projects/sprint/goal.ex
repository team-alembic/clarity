defmodule Demo.Projects.Sprint.Goal do
  @moduledoc """
  An outcome a Sprint commits to. Nested under Sprint, as a resource's own
  records often are, so Clarity groups it with Sprint in its overviews and
  tree.
  """

  use Ash.Resource,
    domain: Demo.Projects,
    data_layer: Ash.DataLayer.Ets

  resource do
    description "An outcome a Sprint commits to, met or not by its end."
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  relationships do
    belongs_to :sprint, Demo.Projects.Sprint, allow_nil?: false
  end

  attributes do
    uuid_primary_key :id

    attribute :summary, :string do
      allow_nil? false
      public? true
      description "The outcome, in a sentence."
    end

    attribute :met?, :boolean do
      public? true
      default false
      description "Whether the Sprint met it."
    end
  end
end
