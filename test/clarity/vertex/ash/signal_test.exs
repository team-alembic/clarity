defmodule Clarity.Vertex.Ash.SignalTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Ash.Signals.Delivery.Inline
  alias Clarity.Vertex
  alias Clarity.Vertex.Ash.Signal
  alias Clarity.Vertex.HintProvider
  alias Clarity.Vertex.Util
  alias Demo.Billing.Invoice
  alias Demo.Billing.Signals
  alias Demo.Billing.Subscription
  alias Demo.Helpdesk.CustomerContact

  @spec signal(atom()) :: Signal.t()
  defp signal(name), do: %Signal{signal_module: Signals, signal: Ash.Signals.Info.signal(Signals, name)}

  describe "protocols" do
    test "identify the signal by its module and name, and name it by its name" do
      vertex = signal(:invoice_paid)

      assert Vertex.id(vertex) == Util.id(Signal, [Signals, :invoice_paid])
      assert Vertex.name(vertex) == "invoice_paid"
      assert Vertex.type_label(vertex) == "Ash.Signals.Signal"
    end

    test "give the hint its icon, phase and payload" do
      vertex = signal(:invoice_paid)

      assert HintProvider.icon(vertex) == :signal

      assert HintProvider.facts(vertex) == [
               {"Phase", "after_transaction"},
               {"Payload", ["signal_id", "invoice_id"]}
             ]
    end

    test "name the signal, its module, description and phase in the tooltip" do
      tooltip = :invoice_paid |> signal() |> Vertex.TooltipProvider.tooltip() |> IO.iodata_to_binary()

      assert tooltip =~ "Signal: `:invoice_paid` in `Demo.Billing.Signals`"
      assert tooltip =~ "An invoice was paid in full."
      assert tooltip =~ "Phase: `:after_transaction`"
    end
  end

  describe inspect(&Signal.references/2) do
    test "lists the signals an action emits" do
      action = Info.action(Invoice, :give_up)

      assert Signal.references(Invoice, action) == [{:emits, Signals, :invoice_written_off}]
    end

    test "lists the signals that listeners run the action for, after those it emits" do
      action = Info.action(Subscription, :final_dunning)

      assert Signal.references(Subscription, action) == [
               {:emits, Signals, :subscription_canceled},
               {:triggers, Signals, :invoice_written_off}
             ]
    end

    test "is empty for an action without signals" do
      assert Signal.references(Invoice, Info.action(Invoice, :read)) == []
    end
  end

  describe inspect(&Signal.listeners/3) do
    test "lists the listeners on a resource that run an action for the signal" do
      assert [%{name: :thank_for_payment}] =
               Signal.listeners(signal(:invoice_paid), CustomerContact, :thank_for_payment)

      assert Signal.listeners(signal(:invoice_paid), CustomerContact, :read) == []
    end
  end

  describe inspect(&Signal.emits/2) do
    test "lists an action's emits of the signal" do
      action = Info.action(Invoice, :finalize)

      assert [%{fields: [invoice_id: :id]}] = Signal.emits(signal(:invoice_finalized), action)
      assert Signal.emits(signal(:invoice_paid), action) == []
    end
  end

  describe inspect(&Signal.delivery_module/1) do
    test "is a delivery's module, with or without options" do
      assert Signal.delivery_module({AshOban.Signals, queue: :default}) == AshOban.Signals
      assert Signal.delivery_module(Inline) == Inline
    end
  end

  describe inspect(&Signal.phase_text/1) do
    test "spells a phase out" do
      assert Signal.phase_text(:after_transaction) == "after transaction"
      assert Signal.phase_text(:before_action) == "before action"
    end
  end
end
