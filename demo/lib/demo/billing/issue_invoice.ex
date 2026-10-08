defmodule Demo.Billing.IssueInvoice do
  @moduledoc """
  Issues a subscription's invoice for the current period and collects it.

  Prices the period by plan (free plans aren't charged), drafts the invoice,
  charges the organization's payment method and emails a receipt. If a later
  step fails, the drafted invoice is undone, and a failed charge is retried
  before giving up. Like `Demo.Accounts.OnboardOrganization`, its steps are
  plain functions: the point is to give Clarity's Reactor diagram a branch,
  an undo and a compensation to draw.

  Inputs:
    * `:subscription_id` — the subscription to bill.
  """

  use Reactor

  input :subscription_id do
    description "The subscription to bill."
  end

  step :load_subscription do
    description "Load the subscription with its plan and seat count."
    argument :id, input(:subscription_id)

    run fn %{id: id}, _context ->
      {:ok, %{id: id, plan: :team, seats: 5, seat_price_cents: 1_200}}
    end
  end

  switch :price_period do
    description "Price the period by plan."
    on result(:load_subscription)

    matches? &(&1.plan == :free) do
      step :no_charge do
        description "Free plans aren't charged."
        run fn _arguments, _context -> {:ok, 0} end
      end

      return :no_charge
    end

    default do
      step :price_seats do
        description "Seats times the plan's seat price."
        argument :subscription, result(:load_subscription)

        run fn %{subscription: subscription}, _context ->
          {:ok, subscription.seats * subscription.seat_price_cents}
        end
      end

      return :price_seats
    end
  end

  step :draft_invoice do
    description "Draft the invoice for the priced period."
    argument :subscription, result(:load_subscription)
    argument :total_cents, result(:price_period)

    run fn %{subscription: subscription, total_cents: total_cents}, _context ->
      {:ok, %{number: "INV-000001", subscription_id: subscription.id, total_cents: total_cents}}
    end

    undo fn _invoice -> :ok end
  end

  step :charge_payment_method do
    description "Charge the organization's default payment method."
    argument :invoice, result(:draft_invoice)
    max_retries 3

    run fn %{invoice: invoice}, _context ->
      {:ok, %{charge_id: "ch_" <> invoice.number, amount_cents: invoice.total_cents}}
    end

    compensate fn _reason -> :retry end
  end

  step :email_receipt do
    description "Email the receipt for the paid invoice."
    argument :invoice, result(:draft_invoice)
    argument :charge, result(:charge_payment_method)

    run fn %{invoice: invoice, charge: charge}, _context ->
      {:ok, %{invoice: invoice.number, charge: charge.charge_id}}
    end
  end

  return :draft_invoice
end
