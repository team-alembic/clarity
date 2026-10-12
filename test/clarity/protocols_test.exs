defmodule Clarity.ProtocolsTest do
  use ExUnit.Case, async: true

  alias Clarity.Protocols
  alias Clarity.Vertex.HintProvider.MyApp.CustomVertex

  describe inspect(&Protocols.implementation?/1) do
    test "is true of a module named for an implementation of a protocol with a fallback" do
      assert Protocols.implementation?(Clarity.Vertex.TooltipProvider.Clarity.Vertex.Module)
      assert Protocols.implementation?(CustomVertex)
    end

    test "is false of other modules" do
      refute Protocols.implementation?(Clarity.Vertex.TooltipProvider)
      refute Protocols.implementation?(Clarity.Vertex.Clarity.Vertex.Module)
      refute Protocols.implementation?(MyApp.CustomVertex)
    end
  end

  describe inspect(&Protocols.consolidate_again/1) do
    test "does nothing unless it consolidated them before" do
      assert :ok = Protocols.consolidate_again([CustomVertex])
      refute Protocol.consolidated?(Clarity.Vertex.HintProvider)
    end
  end
end
