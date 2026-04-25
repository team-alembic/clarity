defmodule Demo.Billing do
  @moduledoc """
  Plans, Subscriptions, Invoices, LineItems, PaymentMethods. Heavy on
  calculations and aggregates: outstanding balances, days overdue, line
  totals, subscription seat counts.
  """

  use Ash.Domain

  resources do
    resource Demo.Billing.Plan
    resource Demo.Billing.Subscription
    resource Demo.Billing.Invoice
    resource Demo.Billing.LineItem
    resource Demo.Billing.PaymentMethod
  end
end
