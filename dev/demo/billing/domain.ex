defmodule Demo.Billing.Domain do
  @moduledoc """
  Plans, Subscriptions, Invoices, LineItems, PaymentMethods. Heavy on
  calculations and aggregates: outstanding balances, days overdue, line
  totals, subscription seat counts.
  """

  use Ash.Domain

  domain do
    description """
    Money: catalog (Plan), commitment (Subscription), and the records
    of charges and payment methods (Invoice, LineItem, PaymentMethod).
    Heavy on calculations and aggregates — outstanding balances, days
    overdue, line totals, subscription seat counts — making this the
    best domain for showcasing those features in the UI.
    """
  end

  resources do
    resource Demo.Billing.Plan
    resource Demo.Billing.Subscription
    resource Demo.Billing.Invoice
    resource Demo.Billing.LineItem
    resource Demo.Billing.PaymentMethod
  end
end
