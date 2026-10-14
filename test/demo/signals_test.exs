defmodule Demo.SignalsWiringTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Ash.Resource.Verifiers.VerifyEmitSignal
  alias Ash.Resource.Verifiers.VerifySignalListeners
  alias Demo.Accounts.AuditEvent
  alias Demo.Billing.Invoice
  alias Demo.Billing.Subscription
  alias Demo.Helpdesk.CustomerContact

  @resources [
    Invoice,
    Subscription,
    AuditEvent,
    CustomerContact
  ]

  test "declares the billing signals, and a platform signal" do
    assert Demo.Billing.Signals |> Ash.Signals.Info.signals() |> Enum.map(& &1.name) == [
             :invoice_finalized,
             :invoice_paid,
             :invoice_written_off,
             :subscription_canceled
           ]

    assert [%{name: :maintenance_scheduled}] = Ash.Signals.Info.signals(Demo.Signals)
  end

  test "emits and listens without a verifier error" do
    for resource <- @resources do
      dsl = resource.spark_dsl_config()
      assert VerifyEmitSignal.verify(dsl) == :ok
      assert VerifySignalListeners.verify(dsl) == :ok
    end
  end

  test "listens through the Inline and AshOban deliveries" do
    assert [
             %{
               name: :cancel_after_write_off,
               action: :final_dunning,
               delivery: {Ash.Signals.Delivery.Inline, []}
             }
           ] = Info.signal_listeners(Subscription)

    assert [%{name: :thank_for_payment, delivery: {AshOban.Signals, [queue: :default]}}] =
             Info.signal_listeners(CustomerContact)

    assert [%{name: :record_subscription_canceled}] = Info.signal_listeners(AuditEvent)
  end

  test "emits from the invoice and subscription lifecycles" do
    assert [%{signal: :invoice_paid, phase: :after_transaction}] =
             Info.action(Invoice, :payment_received).emits

    assert [%{signal: :subscription_canceled}] =
             Info.action(Subscription, :user_cancels).emits
  end
end
