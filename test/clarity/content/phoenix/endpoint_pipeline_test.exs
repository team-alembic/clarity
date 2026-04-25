defmodule Clarity.Content.Phoenix.EndpointPipelineTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Phoenix.EndpointPipeline
  alias Clarity.Vertex.Phoenix.Endpoint
  alias Clarity.Vertex.Root

  describe inspect(&EndpointPipeline.applies?/2) do
    test "true for Phoenix Endpoint vertex" do
      assert EndpointPipeline.applies?(%Endpoint{endpoint: DemoWeb.Endpoint}, nil)
    end

    test "false for non-endpoint vertex" do
      refute EndpointPipeline.applies?(%Root{}, nil)
    end
  end

  describe inspect(&EndpointPipeline.render_static/2) do
    test "rendered D2 source contains the endpoint node" do
      {:d2, render_fn} =
        EndpointPipeline.render_static(%Endpoint{endpoint: DemoWeb.Endpoint}, nil)

      d2 = %{theme: :light, zoom_subgraph: nil} |> render_fn.() |> IO.iodata_to_binary()

      assert d2 =~ "endpoint:"
      assert d2 =~ "shape: rectangle"
    end
  end
end
