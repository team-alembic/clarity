defmodule Clarity.Test.BareArgumentExtension do
  @moduledoc false

  # Adds a calculation whose argument is a plain map, as AshAdmin's
  # `AddPositionSortCalculation` transformer does: Spark's `build_entity/4`
  # does not turn the map into an `Ash.Resource.Calculation.Argument`.

  use Spark.Dsl.Extension, transformers: [Clarity.Test.BareArgumentTransformer]
end
