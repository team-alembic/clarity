defmodule Clarity.Vertex.Ash.SignalModuleTest do
  use ExUnit.Case, async: true

  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.SignalModule
  alias Clarity.Vertex.HintProvider
  alias Clarity.Vertex.Util
  alias Demo.Billing.Signals

  @vertex %SignalModule{signal_module: Signals}

  describe inspect(&SignalModule.signal_module?/1) do
    test "is true of a module that uses Ash.Signals" do
      assert SignalModule.signal_module?(Signals)
    end

    test "is false of other modules, and of modules that don't exist" do
      refute SignalModule.signal_module?(Demo.Billing.Invoice)
      refute SignalModule.signal_module?(Enum)
      refute SignalModule.signal_module?(Clarity.NoSuchModule)
    end
  end

  describe inspect(&SignalModule.in_app/1) do
    test "lists an application's signal modules by name" do
      assert SignalModule.in_app(:clarity) == [Signals, Demo.Signals]
    end

    test "is empty for an application without any, and for none" do
      assert SignalModule.in_app(:logger) == []
      assert SignalModule.in_app(nil) == []
    end
  end

  describe inspect(&SignalModule.domain/1) do
    test "looks among the module's application's domains" do
      assert SignalModule.domain(Signals) == Demo.Billing
      assert SignalModule.domain(Demo.Signals) == nil
    end
  end

  describe "protocols" do
    test "identify and name the vertex by its module" do
      assert Vertex.id(@vertex) == Util.id(SignalModule, [Signals])
      assert Vertex.name(@vertex) == "Demo.Billing.Signals"
      assert Vertex.type_label(@vertex) == "Ash.Signals"
      assert Vertex.ModuleProvider.module(@vertex) == Signals
    end

    test "give the hint its icon and the module's signals" do
      assert HintProvider.icon(@vertex) == :signal_module

      assert HintProvider.facts(@vertex) == [
               {"Signals", ["invoice_finalized", "invoice_paid", "invoice_written_off", "subscription_canceled"]}
             ]
    end

    test "lead the tooltip with the module and its documentation" do
      tooltip = @vertex |> Vertex.TooltipProvider.tooltip() |> IO.iodata_to_binary()

      assert tooltip =~ "`Demo.Billing.Signals`"
      assert tooltip =~ "Other domains react to these"
    end
  end
end
