defmodule Clarity.Content.Ash.StateMachineDiagramTest do
  use ExUnit.Case, async: true

  alias Clarity.Content.Ash.StateMachineDiagram
  alias Clarity.Vertex.Ash.Resource
  alias Clarity.Vertex.Root

  describe inspect(&StateMachineDiagram.applies?/2) do
    test "false when AshStateMachine is not loaded or resource doesn't use it" do
      refute StateMachineDiagram.applies?(%Resource{resource: Demo.Accounts.User}, nil)
    end

    test "false for non-resource vertices" do
      refute StateMachineDiagram.applies?(%Root{}, nil)
    end
  end
end
