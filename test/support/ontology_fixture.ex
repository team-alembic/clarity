defmodule Clarity.Test.OntologyFixture do
  @moduledoc false

  # A minimal Ash resource with public terms of every kind (attribute,
  # calculation, aggregate, relationship), used to exercise
  # `Clarity.Report.Ontology` — the Demo app's calculations, aggregates and
  # relationships are all private (Ash 3 defaults), so they never enter the
  # report's public-only dictionary.

  use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :status, :atom do
      public? true
      constraints one_of: [:draft, :live]

      description "Where the thing is in its lifecycle"
    end

    attribute :secret, :string do
      public? false
      sensitive? true
    end
  end

  actions do
    default_accept :*
    defaults [:read, :create, :update, :destroy]
  end

  relationships do
    belongs_to :parent, __MODULE__ do
      public? true
    end

    has_many :children, __MODULE__ do
      public? true
      destination_attribute :parent_id
    end
  end

  aggregates do
    count :child_count, :children do
      public? true
    end
  end

  calculations do
    calculate :display_name, :string, expr(name) do
      public? true

      description "The name, ready for display"
    end
  end
end
