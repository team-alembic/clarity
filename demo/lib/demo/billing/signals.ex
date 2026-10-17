defmodule Demo.Billing.Signals do
  @moduledoc """
  What happens to invoices and subscriptions. Other domains react to these
  signals, and Billing does not know about them.
  """

  use Ash.Signals

  signals do
    signal :invoice_finalized do
      description "An invoice was finalized and sent to its organization."
      argument :invoice_id, :uuid, allow_nil?: false
      argument :number, :string, allow_nil?: false
    end

    signal :invoice_paid do
      description "An invoice was paid in full."
      phase :after_transaction
      argument :invoice_id, :uuid, allow_nil?: false
    end

    signal :invoice_written_off do
      description "An overdue invoice was written off as uncollectable."
      argument :invoice_id, :uuid, allow_nil?: false
      argument :subscription_id, :uuid, allow_nil?: false
    end

    signal :subscription_canceled do
      description "A subscription was canceled, by its organization or for non-payment."
      argument :subscription_id, :uuid, allow_nil?: false
    end
  end
end
