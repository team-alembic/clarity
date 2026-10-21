defmodule Clarity.Test.BareArgumentFixture do
  @moduledoc false

  # A resource whose calculation has a bare-map argument, the shape AshAdmin
  # gives every resource with a `label_field`. See
  # `Clarity.Test.BareArgumentExtension`.

  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    extensions: [Clarity.Test.BareArgumentExtension]

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
    end
  end

  actions do
    defaults [:read]
  end
end
