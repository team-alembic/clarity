defmodule Clarity.Test.BareArgumentTransformer do
  @moduledoc false

  use Spark.Dsl.Transformer

  import Ash.Expr

  alias Spark.Dsl.Transformer

  @impl Transformer
  def transform(dsl_state) do
    opts = [
      name: :bare_argument_position,
      type: :integer,
      calculation: expr(string_position(^ref(:name), ^arg(:search_term))),
      arguments: [%{name: :search_term, type: :string, constraints: [], default: ""}],
      sortable?: true
    ]

    with {:ok, calculation} <-
           Transformer.build_entity(Ash.Resource.Dsl, [:calculations], :calculate, opts) do
      {:ok, Transformer.add_entity(dsl_state, [:calculations], calculation)}
    end
  end
end
